module EnsureCurrentAccountHelper
  private

  def current_account
    @current_account ||= ensure_current_account
    Current.account = @current_account
  end

  def ensure_current_account
    account = Account.find(params[:account_id])
    render_unauthorized('Account is suspended') and return unless account.active?

    if current_user
      account_accessible_for_user?(account)
    elsif @resource.is_a?(AgentBot)
      account_accessible_for_bot?(account)
    end
    account
  end

  def account_accessible_for_user?(account)
    @current_account_user = account.account_users.find_by(user_id: current_user.id)
    Current.account_user = @current_account_user
    return render_unauthorized('You are not authorized to access this account') unless @current_account_user

    # Banking demo: hard-stop suspended users on every authenticated request,
    # not just outbound replies. Prevents browsing, assigning, self-unsuspend,
    # etc. while AccountUser.suspended_at is set.
    render_unauthorized('Your account is suspended. Contact your administrator.') if @current_account_user.suspended?
  end

  def account_accessible_for_bot?(account)
    return if @resource.account_id == account.id
    return if @resource.agent_bot_inboxes.find_by(account_id: account.id)

    render_unauthorized('Bot is not authorized to access this account')
  end
end
