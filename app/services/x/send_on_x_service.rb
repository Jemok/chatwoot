# Sends outgoing replies to X (Twitter) using OAuth 1.0a user-context.
# - Tweet replies: POST /2/tweets with reply.in_reply_to_tweet_id
# - Direct messages: POST /2/dm_conversations/with/:participant_id/messages
class X::SendOnXService < Base::SendOnChannelService
  private

  def channel_class
    Channel::X
  end

  def perform_reply
    return if message.content.blank?

    if dm_conversation?
      send_direct_message
    else
      send_tweet_reply
    end
  rescue StandardError => e
    handle_error(e)
  end

  def dm_conversation?
    conversation.additional_attributes&.dig('type') == 'x_direct_message'
  end

  def send_tweet_reply
    response = signed_post(
      'https://api.twitter.com/2/tweets',
      { text: message.outgoing_content, reply: { in_reply_to_tweet_id: reply_to_id } }.to_json
    )
    parsed = parse_response(response)

    if success?(response) && parsed.is_a?(Hash) && parsed['data']
      message.update!(source_id: parsed.dig('data', 'id'))
    else
      record_failure(parsed, 'send_tweet_reply', response.code.to_i)
    end
  end

  def send_direct_message
    participant_id = conversation.contact_inbox.source_id
    response = signed_post(
      "https://api.twitter.com/2/dm_conversations/with/#{participant_id}/messages",
      { text: message.outgoing_content }.to_json
    )
    parsed = parse_response(response)

    if success?(response) && parsed.is_a?(Hash) && parsed['data']
      message.update!(source_id: parsed.dig('data', 'dm_event_id'))
    else
      record_failure(parsed, 'send_direct_message', response.code.to_i)
    end
  end

  def signed_post(url, body)
    channel.oauth_access_token.post(url, body, 'Content-Type' => 'application/json', 'Accept' => 'application/json')
  end

  def parse_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    response.body
  end

  def success?(response)
    response.code.to_i.between?(200, 299)
  end

  def reply_to_id
    attrs = message.content_attributes || {}
    return attrs['in_reply_to_external_id'] if attrs['in_reply_to_external_id'].present?

    last_incoming = conversation.messages.incoming.where.not(source_id: nil).order(created_at: :desc).first
    last_incoming&.source_id || conversation.identifier
  end

  def record_failure(parsed, context, status_code)
    error_message = parsed.is_a?(Hash) ? (parsed['detail'] || parsed['title'] || parsed.to_s) : parsed.to_s
    channel.authorization_error! if status_code == 401

    Rails.logger.error("[X::SendOnXService] #{context} failed: #{status_code} - #{error_message}")
    Messages::StatusUpdateService.new(message, 'failed', "#{status_code} - #{error_message}").perform
  end

  def handle_error(error)
    ChatwootExceptionTracker.new(error, account: message.account, user: message.sender).capture_exception
  end
end
