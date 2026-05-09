class Api::V1::Accounts::Inboxes::Facebook::ExternalMessagesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :ensure_supported_inbox
  before_action :validate_required_message_fields
  before_action :fetch_conversation, only: [:create]
  before_action :resolve_conversation_from_external_user, only: [:create_by_external_user]

  def create
    create_or_render_existing_message
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def create_by_external_user
    create_or_render_existing_message
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
  end

  def ensure_supported_inbox
    return if supported_inbox?

    render json: { error: 'This endpoint supports Facebook Messenger DM, Instagram DM, and WhatsApp inboxes only' },
           status: :unprocessable_entity
  end

  def fetch_conversation
    @conversation = @inbox.conversations.find(message_params[:conversation_id])
    ensure_messenger_conversation
  end

  def validate_required_message_fields
    has_base_fields = message_params[:content].present? && message_params[:source_id].present?
    has_target = action_name == 'create' ? message_params[:conversation_id].present? : message_params[:external_user_id].present?
    return if has_base_fields && has_target

    render json: { error: validation_error_message }, status: :unprocessable_entity
  end

  def validation_error_message
    return 'message.content, message.source_id and message.conversation_id are required' if action_name == 'create'

    'message.content, message.source_id and message.external_user_id are required'
  end

  def message_params
    params.require(:message).permit(:conversation_id, :external_user_id, :external_user_name, :content, :source_id, :external_created_at,
                                    :relay_source)
  end

  def resolve_conversation_from_external_user
    # Only set the contact name when creating a new contact (i.e., no prior contact_inbox
    # exists for this external user). If a conversation is already in place we must not
    # overwrite the existing contact's name with whatever the caller supplied.
    existing_contact_inbox = @inbox.contact_inboxes.find_by(source_id: message_params[:external_user_id])
    contact_attributes = existing_contact_inbox ? {} : { name: message_params[:external_user_name] }

    contact_inbox = ContactInboxWithContactBuilder.new(
      source_id: message_params[:external_user_id],
      inbox: @inbox,
      contact_attributes: contact_attributes
    ).perform

    @conversation = existing_messenger_conversation(contact_inbox) || create_conversation(contact_inbox)
  end

  def existing_messenger_conversation(contact_inbox)
    scope = Conversation.where(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: contact_inbox.contact_id
    ).order(created_at: :desc)

    scope = scope.where("COALESCE(additional_attributes ->> 'type', '') != ?", 'instagram_direct_message') if @inbox.facebook?

    return scope.first if @inbox.lock_to_single_conversation

    scope.where.not(status: :resolved).first
  end

  def create_conversation(contact_inbox)
    Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id
    )
  end

  def create_or_render_existing_message
    existing_message = @conversation.messages.find_by(source_id: message_params[:source_id])
    return render_message(existing_message, :ok) if existing_message

    message = Messages::MessageBuilder.new(nil, @conversation, builder_params).perform
    render_message(message, :created)
  end

  def ensure_messenger_conversation
    return unless @inbox.facebook? && @conversation.additional_attributes['type'] == 'instagram_direct_message'

    render json: { error: 'This endpoint is only for Messenger conversations' }, status: :unprocessable_entity
  end

  def supported_inbox?
    return true if @inbox.whatsapp?
    return true if @inbox.instagram_direct? && @inbox.queue_kind.in?([nil, 'dm'])

    @inbox.facebook? && @inbox.queue_kind == 'dm'
  end

  def builder_params
    ActionController::Parameters.new(
      content: message_params[:content],
      message_type: 'outgoing',
      source_id: message_params[:source_id],
      external_created_at: message_params[:external_created_at],
      sender_type: 'AgentBot',
      sender_id: ai_agent_bot.id,
      content_attributes: {
        external_echo: true,
        ai_generated: true,
        relay_source: message_params[:relay_source]
      }.compact
    )
  end

  def ai_agent_bot
    @ai_agent_bot ||= Current.account.agent_bots.find_or_create_by!(name: 'Messenger AI Relay') do |bot|
      bot.description = 'System bot used for ingesting externally generated Messenger replies'
      bot.bot_type = 'webhook'
    end
  end

  def render_message(message, status)
    render json: {
      id: message.id,
      conversation_id: message.conversation_id,
      message_type: message.message_type,
      sender_type: message.sender_type,
      content: message.content,
      source_id: message.source_id,
      content_attributes: message.content_attributes
    }, status: status
  end
end
