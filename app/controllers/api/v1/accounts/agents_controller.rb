class Api::V1::Accounts::AgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_agent, except: [:create, :index, :bulk_create]
  before_action :check_authorization
  before_action :validate_limit, only: [:create]
  before_action :validate_limit_for_bulk_create, only: [:bulk_create]

  def index
    @agents = agents
  end

  def create
    builder = AgentBuilder.new(
      email: new_agent_params['email'],
      name: new_agent_params['name'],
      role: new_agent_params['role'],
      availability: new_agent_params['availability'],
      auto_offline: new_agent_params['auto_offline'],
      inviter: current_user,
      account: Current.account
    )

    @agent = builder.perform
  end

  def update
    @agent.update!(agent_params.slice(:name).compact)
    @agent.current_account_user.update!(agent_params.slice(*account_user_attributes).compact)
  end

  def destroy
    @agent.current_account_user.destroy!
    delete_user_record(@agent)
    head :ok
  end

  # Banking demo: temporarily disable an agent. Sets suspended_at + flips
  # availability offline + rotates pubsub_token so existing browser tabs lose
  # their cable subscription on next reconnect. Audited as user_lifecycle.
  def suspend
    authorize_admin!
    au = @agent.account_users.find_by(account_id: Current.account.id)
    au.update!(suspended_at: Time.current, suspended_reason: params[:reason].presence)
    au.update_columns(availability: AccountUser.availabilities[:offline]) unless au.offline?
    # Nuke active logins: rotate pubsub_token (cable) + clear devise_token_auth
    # tokens so any open browser tab is signed out on its next API call.
    @agent.update!(pubsub_token: SecureRandom.uuid, tokens: {})
    audit_lifecycle('suspend', "reason=#{params[:reason]}")
    head :ok
  end

  def reinstate
    authorize_admin!
    au = @agent.account_users.find_by(account_id: Current.account.id)
    au.update!(suspended_at: nil, suspended_reason: nil)
    audit_lifecycle('reinstate', nil)
    head :ok
  end

  def bulk_create
    emails = params[:emails]

    emails.each do |email|
      builder = AgentBuilder.new(
        email: email,
        name: email.split('@').first,
        inviter: current_user,
        account: Current.account
      )
      begin
        builder.perform
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.info "[Agent#bulk_create] ignoring email #{email}, errors: #{e.record.errors}"
      end
    end

    # This endpoint is used to bulk create agents during onboarding
    # onboarding_step key in present in Current account custom attributes, since this is a one time operation
    Current.account.custom_attributes.delete('onboarding_step')
    Current.account.save!
    head :ok
  end

  private

  def check_authorization
    super(User)
  end

  def fetch_agent
    @agent = agents.find(params[:id])
  end

  def account_user_attributes
    [:role, :availability, :auto_offline]
  end

  def allowed_agent_params
    [:name, :email, :role, :availability, :auto_offline]
  end

  def agent_params
    params.require(:agent).permit(allowed_agent_params)
  end

  def new_agent_params
    params.require(:agent).permit(:email, :name, :role, :availability, :auto_offline)
  end

  def agents
    @agents ||= Current.account.users.order_by_full_name.includes(:account_users, { avatar_attachment: [:blob] })
  end

  def validate_limit_for_bulk_create
    limit_available = params[:emails].count <= available_agent_count

    render_payment_required('Account limit exceeded. Please purchase more licenses') unless limit_available
  end

  def validate_limit
    render_payment_required('Account limit exceeded. Please purchase more licenses') unless can_add_agent?
  end

  def available_agent_count
    Current.account.usage_limits[:agents] - agents.count
  end

  def can_add_agent?
    available_agent_count.positive?
  end

  def delete_user_record(agent)
    DeleteObjectJob.perform_later(agent) if agent.reload.account_users.blank?
  end

  def authorize_admin!
    return if Current.account_user&.administrator?

    render json: { error: 'Administrator access required' }, status: :forbidden
  end

  def audit_lifecycle(action, details)
    PolicyViolationLog.create!(
      account_id: Current.account.id,
      user_id: Current.user&.id,
      policy: 'user_lifecycle',
      action_attempted: action,
      details: "target_user_id=#{@agent.id} #{details}",
      request_ip: request.remote_ip
    )
  end
end

Api::V1::Accounts::AgentsController.prepend_mod_with('Api::V1::Accounts::AgentsController')
