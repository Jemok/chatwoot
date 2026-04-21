# Banking demo: unified message edit + delete service that persists the
# change locally AND, when the underlying channel supports it, propagates to
# the external platform (Telegram is the main one — FB Messenger / Instagram
# allow delete-only, WhatsApp/Twilio/email have no native edit).
#
# Channels without native support fall back to a simulated edit: the local
# content is updated (so the dashboard reflects it) and the result is flagged
# `simulated: true` so the UI/audit log can surface that the external
# recipient still sees the original text.
class Messages::EditService
  # Telegram rejects edits older than 48h.
  TELEGRAM_EDIT_WINDOW = 48.hours

  CHANNELS_WITH_NATIVE_EDIT = %w[Channel::Telegram].freeze
  CHANNELS_WITH_NATIVE_DELETE = %w[Channel::Telegram Channel::FacebookPage].freeze

  pattr_initialize [:message!, :user, :new_content, :action]

  def perform!
    case action.to_s
    when 'edit' then perform_edit!
    when 'delete' then perform_delete!
    else raise ArgumentError, "Unsupported action: #{action}"
    end
  end

  private

  def perform_edit!
    raise ArgumentError, 'new_content is blank' if new_content.blank?
    raise ArgumentError, 'Only outgoing text replies can be edited' unless outgoing_text?

    original = message.content
    native_result = dispatch_native_edit
    attrs = message.content_attributes.deep_dup || {}
    attrs['original_content'] ||= original
    attrs['edited'] = true
    attrs['edited_at'] = Time.current.iso8601
    attrs['edited_by_user_id'] = user&.id
    attrs['edit_history'] = (attrs['edit_history'] || []) + [{
      'content' => original,
      'edited_at' => Time.current.iso8601,
      'edited_by_user_id' => user&.id
    }]
    attrs['edit_simulated'] = native_result[:simulated]
    message.update!(content: new_content, content_attributes: attrs)

    audit('edit', native_result[:simulated])
    native_result.merge(message_id: message.id, action: 'edit')
  end

  def perform_delete!
    native_result = dispatch_native_delete
    attrs = message.content_attributes.deep_dup || {}
    attrs['original_content'] ||= message.content
    attrs['deleted'] = true
    attrs['deleted_at'] = Time.current.iso8601
    attrs['deleted_by_user_id'] = user&.id
    attrs['delete_simulated'] = native_result[:simulated]
    ActiveRecord::Base.transaction do
      message.update!(
        content: I18n.t('conversations.messages.deleted'),
        content_type: :text,
        content_attributes: attrs
      )
      message.attachments.destroy_all
    end

    audit('delete', native_result[:simulated])
    native_result.merge(message_id: message.id, action: 'delete')
  end

  def outgoing_text?
    message.outgoing? && message.content_type.to_s == 'text'
  end

  def channel_type
    message.inbox.channel_type
  end

  # --- Native edit dispatch -------------------------------------------------
  def dispatch_native_edit
    return { simulated: true, reason: 'channel_unsupported' } unless CHANNELS_WITH_NATIVE_EDIT.include?(channel_type)
    return { simulated: true, reason: 'no_source_id' } if message.source_id.blank?
    return { simulated: true, reason: 'edit_window_expired' } if message.created_at < TELEGRAM_EDIT_WINDOW.ago

    case channel_type
    when 'Channel::Telegram' then telegram_edit
    else { simulated: true, reason: 'channel_unsupported' }
    end
  end

  def telegram_edit
    channel = message.inbox.channel
    response = HTTParty.post(
      "#{channel.telegram_api_url}/editMessageText",
      body: {
        chat_id: channel.chat_id(message),
        message_id: message.source_id,
        text: new_content,
        parse_mode: 'HTML'
      }
    )
    if response.success?
      { simulated: false, provider: 'telegram' }
    else
      { simulated: true, reason: "telegram_error:#{response.parsed_response['description']}" }
    end
  end

  # --- Native delete dispatch ----------------------------------------------
  def dispatch_native_delete
    return { simulated: true, reason: 'channel_unsupported' } unless CHANNELS_WITH_NATIVE_DELETE.include?(channel_type)
    return { simulated: true, reason: 'no_source_id' } if message.source_id.blank?

    case channel_type
    when 'Channel::Telegram' then telegram_delete
    when 'Channel::FacebookPage' then facebook_unsend
    else { simulated: true, reason: 'channel_unsupported' }
    end
  end

  def telegram_delete
    channel = message.inbox.channel
    response = HTTParty.post(
      "#{channel.telegram_api_url}/deleteMessage",
      body: { chat_id: channel.chat_id(message), message_id: message.source_id }
    )
    if response.success?
      { simulated: false, provider: 'telegram' }
    else
      { simulated: true, reason: "telegram_error:#{response.parsed_response['description']}" }
    end
  end

  # Facebook Messenger unsend is only allowed for messages sent <24h ago via
  # the Page access token. We keep this best-effort; failures fall back to
  # simulated.
  def facebook_unsend
    channel = message.inbox.channel
    response = HTTParty.delete(
      "https://graph.facebook.com/v18.0/#{message.source_id}",
      query: { access_token: channel.page_access_token }
    )
    if response.success?
      { simulated: false, provider: 'facebook' }
    else
      { simulated: true, reason: "facebook_error:#{response.parsed_response.dig('error', 'message')}" }
    end
  end

  def audit(action_type, simulated)
    PolicyViolationLog.create!(
      account_id: message.account_id,
      user_id: user&.id,
      conversation_id: message.conversation_id,
      inbox_id: message.inbox_id,
      policy: 'moderation_action',
      action_attempted: "message.#{action_type}",
      details: "channel=#{channel_type} simulated=#{simulated} source_id=#{message.source_id}"
    )
  end
end
