# Banking demo (#4): admin-managed registry of blocked/restricted profiles
# across Facebook + X channels. Platform-side block is simulated by default;
# local state always reflects the block (badge + label routing).
class Api::V1::Accounts::BlockedProfilesController < Api::V1::Accounts::BaseController
  before_action :set_record, only: [:destroy]

  def index
    authorize BlockedProfile, :index?
    scope = Current.account.blocked_profiles.order(id: :desc)
    scope = scope.where(channel_type: params[:channel_type]) if params[:channel_type].present?
    render json: scope.as_json(methods: [:active?])
  end

  def create
    authorize BlockedProfile, :create?
    attrs = resolve_block_attrs
    record = Current.account.blocked_profiles.new(
      attrs.merge(blocked_by_user_id: Current.user&.id, blocked_until: parse_until(params[:duration_hours]))
    )
    record.save!
    platform_result = Profiles::BlockService.new(blocked_profile: record, inbox: @inbox).perform!
    audit('block', record, params[:reason], platform_result)
    render json: record.as_json(methods: [:active?]).merge(platform: platform_result), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @record, :destroy?
    @record.destroy!
    audit('unblock', @record, nil, nil)
    head :ok
  end

  private

  def set_record
    @record = Current.account.blocked_profiles.find(params[:id])
  end

  def blocked_profile_params
    params.require(:blocked_profile).permit(:channel_type, :platform_user_id, :contact_id, :reason)
  end

  # Banking demo: allow the inline "Block profile" action to pass just a
  # conversation_id — we resolve channel_type + platform_user_id from the
  # conversation's ContactInbox so agents don't have to paste IDs.
  def resolve_block_attrs
    explicit = blocked_profile_params.to_h
    conversation_id = params[:conversation_id]
    return explicit if conversation_id.blank?

    conversation = Current.account.conversations.find(conversation_id)
    @inbox = conversation.inbox
    contact_inbox = conversation.contact_inbox
    explicit.merge(
      channel_type: explicit[:channel_type].presence || @inbox.channel_type,
      platform_user_id: explicit[:platform_user_id].presence || contact_inbox&.source_id,
      contact_id: explicit[:contact_id].presence || conversation.contact_id
    )
  end

  def parse_until(hours)
    hours.to_f.positive? ? Time.current + hours.to_f.hours : nil
  end

  def audit(action, record, reason, platform_result)
    details = [
      "channel=#{record.channel_type}",
      "platform_user_id=#{record.platform_user_id}",
      reason.present? ? "reason=#{reason}" : nil,
      platform_result ? "simulated=#{platform_result[:simulated]}" : nil,
      platform_result && platform_result[:reason] ? "note=#{platform_result[:reason]}" : nil
    ].compact.join(' ')
    PolicyViolationLog.create!(
      account_id: Current.account.id,
      user_id: Current.user&.id,
      policy: 'profile_block',
      action_attempted: action,
      details: details,
      request_ip: request.remote_ip
    )
  end
end

Api::V1::Accounts::BlockedProfilesController.prepend_mod_with('Api::V1::Accounts::BlockedProfilesController')
