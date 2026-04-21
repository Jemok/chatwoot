# Banking demo: synthesize a "shift just ended" event for the current user so
# the dashboard tab observably switches to "off shift" + the audit table gets
# a fresh row, without waiting for the cron job. Creates a finished shift in
# the last 60s, sets the current account_user offline, broadcasts the cable
# event, and writes a user_lifecycle audit entry — the same exact code path
# used by the production Shifts::ScheduleSweepJob.
class Demo::Simulators::ShiftEndForceLogoutService < Demo::Simulators::BaseService
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def perform!
    target_user = pick_target_user
    raise 'No agent user found in account' if target_user.nil?

    shift = Shift.create!(
      account_id: account.id,
      user_id: target_user.id,
      starts_at: 30.minutes.ago,
      ends_at: 30.seconds.ago,
      status: 'completed',
      recurrence: 'once',
      timezone: ENV.fetch('BANK_DEMO_SHIFT_TZ', Time.zone.name)
    )

    account_user = AccountUser.find_by(account_id: account.id, user_id: target_user.id)
    account_user.update_columns(availability: AccountUser.availabilities[:offline]) unless account_user.offline? # rubocop:disable Rails/SkipsModelValidations
    OnlineStatusTracker.set_status(account.id, target_user.id, 'offline')

    ActionCableBroadcastJob.perform_later(
      [target_user.pubsub_token].compact,
      'user.shift.ended',
      { account_id: account.id, user_id: target_user.id, shift_id: shift.id }
    )

    PolicyViolationLog.create!(
      account_id: account.id,
      user_id: target_user.id,
      policy: 'user_lifecycle',
      action_attempted: 'shift_force_logout',
      details: "Simulated end of shift #{shift.id} (user_id=#{target_user.id})"
    )

    {
      target_user_id: target_user.id,
      target_user_email: target_user.email,
      shift_id: shift.id,
      message: "User pushed offline; their dashboard will show 'Shift ended' banner on the next cable beat."
    }
  end

  private

  # Default to a non-admin agent so the demo shows the off-shift block, not
  # the admin-bypass. Caller can override via payload[:user_id].
  def pick_target_user
    return account.users.find(payload[:user_id]) if payload[:user_id].present?

    agent_id = AccountUser.where(account_id: account.id, role: AccountUser.roles[:agent]).pick(:user_id)
    User.find_by(id: agent_id) || account.users.first
  end
end
