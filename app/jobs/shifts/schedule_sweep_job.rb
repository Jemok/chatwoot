# Runs every minute. Idempotently transitions shift status and enforces
# agent availability based on the wall clock — regardless of whether the
# job ran exactly at the boundary, so shifts that ended while the worker
# was down still get processed on the next tick.
#
# Transitions:
#   scheduled → active     when starts_at <= now < ends_at
#                          + auto-reinstate agent iff suspended with
#                            reason='shift_ended' (system-set suspension)
#   (scheduled|active) → completed   when ends_at <= now
#                          + auto-suspend agent (suspended_at + reason=
#                            'shift_ended'), force offline, rotate
#                            pubsub_token, clear devise_token_auth tokens
#                            so open tabs are 401'd, broadcast
#                            `user.shift.ended`. Skipped when the user
#                            has another overlapping active shift.
class Shifts::ScheduleSweepJob < ApplicationJob
  queue_as :scheduled_jobs

  AUTO_SUSPEND_REASON = 'shift_ended'.freeze

  def perform
    now = Time.current
    activate_due_shifts(now)
    complete_ended_shifts(now)
  end

  private

  def activate_due_shifts(now)
    Shift.where(status: 'scheduled')
         .where('starts_at <= ? AND ends_at > ?', now, now)
         .includes(:user, :account).find_each do |shift|
      shift.update!(status: 'active')
      next if shift.user.nil? || shift.account.nil?

      account_user = AccountUser.find_by(account_id: shift.account_id, user_id: shift.user_id)
      next if account_user.nil?
      next unless account_user.suspended_reason == AUTO_SUSPEND_REASON

      reinstate_agent!(shift, account_user)
    end
  end

  def complete_ended_shifts(now)
    Shift.where(status: %w[scheduled active])
         .where('ends_at <= ?', now)
         .includes(:user, :account).find_each do |shift|
      shift.update!(status: 'completed')
      next if shift.user.nil? || shift.account.nil?
      next if Shift.user_on_duty?(shift.user, shift.account) # back-to-back shift, skip suspend

      account_user = AccountUser.find_by(account_id: shift.account_id, user_id: shift.user_id)
      next if account_user.nil?
      next if account_user.suspended_at.present? # already suspended (admin or earlier sweep)

      suspend_agent!(shift, account_user)
    end
  end

  def suspend_agent!(shift, account_user)
    account_user.update!(suspended_at: Time.current, suspended_reason: AUTO_SUSPEND_REASON)
    account_user.update_columns(availability: AccountUser.availabilities[:offline]) unless account_user.offline? # rubocop:disable Rails/SkipsModelValidations
    OnlineStatusTracker.set_status(shift.account_id, shift.user_id, 'offline')

    shift.user.update!(pubsub_token: SecureRandom.uuid, tokens: {})

    ActionCableBroadcastJob.perform_later(
      [shift.user.pubsub_token].compact,
      'user.shift.ended',
      { account_id: shift.account_id, user_id: shift.user_id, shift_id: shift.id }
    )

    PolicyViolationLog.create!(
      account_id: shift.account_id,
      user_id: shift.user_id,
      policy: 'user_lifecycle',
      action_attempted: 'shift_auto_suspend',
      details: "Shift #{shift.id} ended; agent auto-suspended"
    )
  end

  def reinstate_agent!(shift, account_user)
    account_user.update!(suspended_at: nil, suspended_reason: nil)

    PolicyViolationLog.create!(
      account_id: shift.account_id,
      user_id: shift.user_id,
      policy: 'user_lifecycle',
      action_attempted: 'shift_auto_reinstate',
      details: "Shift #{shift.id} started; agent auto-reinstated"
    )
  end
end
