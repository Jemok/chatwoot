# Returns the shift-driven status of a user in a given account:
#   :disabled  - user has no account_user (removed)
#   :suspended - account_user is suspended
#   :off_shift - shift enforcement is on AND user has no current shift
#   :on_duty   - either no enforcement, or user has a current shift
#
# Used by the off-shift reply guard in MessagesController and by the
# UsersLifecycle admin page to render status pills.
class Shifts::EnforcementService
  def initialize(user:, account:)
    @user = user
    @account = account
  end

  def status
    return :disabled if account_user.nil?
    return :suspended if account_user.suspended?
    return :on_duty unless Shift.shift_enforcement_active?(@account)

    Shift.user_on_duty?(@user, @account) ? :on_duty : :off_shift
  end

  def can_send_messages?
    status == :on_duty
  end

  private

  def account_user
    @account_user ||= AccountUser.find_by(account_id: @account&.id, user_id: @user&.id)
  end
end
