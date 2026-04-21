class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_api_inbox, only: :update
  before_action :enforce_messaging_window!, only: :create
  before_action :enforce_conversation_lock!, only: :create
  before_action :enforce_shift!, only: :create

  # Banking demo: surface edit/delete validation errors as JSON 422.
  rescue_from ArgumentError do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def index
    @messages = message_finder.perform
  end

  # Banking demo: edit an outgoing reply. Persists the change locally and,
  # when the channel supports it (Telegram today), propagates to the remote
  # platform. Unsupported channels fall back to simulated edit.
  def edit
    authorize message, :edit?
    new_content = params[:content].to_s
    result = Messages::EditService.new(
      message: message,
      user: Current.user,
      new_content: new_content,
      action: 'edit'
    ).perform!
    render json: result
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
    @message = message
  end

  def destroy
    authorize message, :destroy?
    result = Messages::EditService.new(message: message, user: Current.user, action: 'delete').perform!
    render json: result.merge(reason: params[:reason])
  end

  # Banking demo (#2, #3, #10): unified moderation endpoint for public-comment
  # channels. Dispatches to FB/IG/TikTok services where available, otherwise
  # updates local state + audits as simulated.
  def moderate
    authorize message, :moderate?
    action_type = params[:action_type].to_s
    return render json: { error: 'action_type must be hide|unhide|delete' }, status: :unprocessable_entity unless %w[hide unhide
                                                                                                                     delete].include?(action_type)

    klass = moderation_service_class
    result = if klass
               klass.new(message: message, user: Current.user, action: action_type).perform!
             else
               simulate_local_moderation!(action_type)
             end
    render json: result.merge(message_id: message.id, reason: params[:reason])
  end

  def retry
    return if message.blank?

    service = Messages::StatusUpdateService.new(message, 'sent')
    service.perform
    message.update!(content_attributes: {})
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def moderation_service_class
    case @conversation.inbox.channel_type
    when 'Channel::FacebookPage' then Facebook::ModerationService
    when 'Channel::Instagram' then Instagram::ModerationService
    when 'Channel::Tiktok' then Tiktok::ModerationService
    end
  end

  def simulate_local_moderation!(action_type)
    attrs = (message.content_attributes || {}).deep_dup
    attrs['original_content'] ||= message.content
    attrs['moderation'] = { 'action' => action_type, 'by_user_id' => Current.user&.id, 'at' => Time.current.iso8601, 'simulated' => true }
    new_content = case action_type
                  when 'delete' then I18n.t('conversations.messages.deleted')
                  when 'hide'   then I18n.t('conversations.messages.hidden_by_moderation', default: '[Hidden by moderation]')
                  when 'unhide' then attrs['original_content']
                  end
    message.update!(content: new_content, content_attributes: attrs.merge('moderated' => action_type != 'unhide'))
    log_moderation_audit(action_type, simulated: true, reason: params[:reason])
    { ok: true, simulated: true, action: action_type, source_id: message.source_id }
  end

  def log_moderation_audit(action_type, simulated:, reason: nil)
    PolicyViolationLog.create!(
      account_id: message.account_id,
      user_id: Current.user&.id,
      conversation_id: message.conversation_id,
      inbox_id: message.inbox_id,
      policy: 'moderation_action',
      action_attempted: "local.#{action_type}",
      details: ["simulated=#{simulated}", reason.present? ? "reason=#{reason}" : nil].compact.join(' ')
    )
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error, :content)
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end

  # Banking demo (#4): hard-block outgoing non-template messages on FB/IG/WA when
  # the platform messaging window has expired. Defends against direct-API bypass
  # of the UI gate (which already hides the reply box via `can_reply: false`).
  def enforce_messaging_window!
    return unless params[:message_type].to_s == 'outgoing' || params[:message_type].blank?
    return if params.dig(:content_attributes, :template_params).present? || params[:template_params].present?
    return unless WINDOW_ENFORCED_CHANNELS.include?(@conversation.inbox.channel_type)
    return if @conversation.can_reply?

    policy = window_policy_for(@conversation.inbox.channel_type)
    PolicyViolationLog.create!(
      account_id: Current.account.id,
      user_id: Current.user&.id,
      conversation_id: @conversation.id,
      inbox_id: @conversation.inbox_id,
      policy: policy,
      action_attempted: 'POST messages (outgoing free-form)',
      details: 'Reply blocked — messaging window expired. Use template/re-engagement flow.',
      request_ip: request.remote_ip
    )
    render json: {
      error: I18n.t('conversations.messages.messaging_window_expired',
                    default: 'Free-form reply blocked — messaging window has expired. Send an approved template to re-engage.'),
      policy: policy,
      requires_template: true
    }, status: :unprocessable_entity
  end

  # Banking demo (Phase 2 #9): block outgoing replies when the agent is off-shift
  # OR suspended. Administrators are exempt from off-shift, but suspended admins
  # are still blocked.
  def enforce_shift!
    return unless params[:message_type].to_s == 'outgoing' || params[:message_type].blank?

    status = Shifts::EnforcementService.new(user: Current.user, account: Current.account).status

    if status == :suspended
      audit_block('account_user is suspended')
      return render json: { error: 'Your account is suspended. Contact your administrator.' }, status: :forbidden
    end

    return if Current.account_user&.administrator?
    return if status == :on_duty || status == :disabled

    audit_block('Agent attempted to reply outside their scheduled shift')
    render json: { error: 'You are off-shift. Replies are disabled until your next scheduled shift.' }, status: :forbidden
  end

  def audit_block(details)
    PolicyViolationLog.create!(
      account_id: Current.account.id,
      user_id: Current.user&.id,
      conversation_id: @conversation.id,
      inbox_id: @conversation.inbox_id,
      policy: 'denied_action',
      action_attempted: 'POST messages (off-shift/suspended)',
      details: details,
      request_ip: request.remote_ip
    )
  end

  WINDOW_ENFORCED_CHANNELS = %w[Channel::Whatsapp Channel::FacebookPage Channel::Instagram Channel::TwilioSms].freeze

  def window_policy_for(channel_type)
    case channel_type
    when 'Channel::Whatsapp', 'Channel::TwilioSms' then 'whatsapp_24h'
    when 'Channel::FacebookPage' then 'facebook_7d'
    when 'Channel::Instagram' then 'facebook_7d'
    end
  end

  # Banking demo (#7): block outgoing message creation when another agent
  # holds the conversation lock. Defense-in-depth — UI also disables ReplyBox.
  def enforce_conversation_lock!
    return unless params[:message_type].to_s == 'outgoing' || params[:message_type].blank?
    return if params[:private]

    lock = ConversationLock.active.find_by(conversation_id: @conversation.id)
    return unless lock
    return if lock.user_id == Current.user&.id

    PolicyViolationLog.create!(
      account_id: Current.account.id,
      user_id: Current.user&.id,
      conversation_id: @conversation.id,
      inbox_id: @conversation.inbox_id,
      policy: 'denied_action',
      action_attempted: 'POST messages (collision)',
      details: "Reply blocked — conversation locked by #{lock.user&.name}",
      request_ip: request.remote_ip
    )
    render json: {
      error: 'Conversation is currently locked by another agent.',
      locked_by: lock.user&.name,
      expires_at: lock.expires_at.to_i
    }, status: :conflict
  end
end
