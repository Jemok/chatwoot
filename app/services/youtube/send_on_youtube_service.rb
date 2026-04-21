# Posts a reply to a YouTube comment using POST /youtube/v3/comments?part=snippet.
# Threads under conversation.identifier (top-level comment) when no in_reply_to is set,
# otherwise replies to the specific incoming comment via parentId = source_id.
class Youtube::SendOnYoutubeService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Youtube
  end

  def perform_reply
    return if message.content.blank?
    return if parent_comment_id.blank?

    response = post_comment
    parsed = parse(response)

    if response.success? && parsed['id'].present?
      message.update!(source_id: parsed['id'])
    else
      record_failure(parsed, response.code)
    end
  rescue StandardError => e
    handle_error(e)
  end

  def post_comment
    HTTParty.post(
      'https://www.googleapis.com/youtube/v3/comments',
      query: { part: 'snippet' },
      body: { snippet: { parentId: parent_comment_id, textOriginal: message.outgoing_content } }.to_json,
      headers: {
        'Authorization' => "Bearer #{channel.access_token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    )
  end

  # When replying to a specific incoming comment, parent under it; otherwise
  # use the conversation's top-level comment (the first incoming message).
  def parent_comment_id
    attrs = message.content_attributes || {}
    return attrs['in_reply_to_external_id'] if attrs['in_reply_to_external_id'].present?

    if attrs['in_reply_to'].present?
      msg = ::Message.find_by(id: attrs['in_reply_to'])
      return msg.source_id if msg&.source_id.present?
    end

    conversation.messages.where(message_type: :incoming).where.not(source_id: nil).order(:created_at).first&.source_id
  end

  def parse(response)
    JSON.parse(response.body)
  rescue StandardError
    {}
  end

  def record_failure(parsed, status_code)
    channel.authorization_error! if status_code.to_i == 401
    err = parsed.dig('error', 'message') || parsed['message'] || 'unknown error'
    Rails.logger.error("[Youtube::SendOnYoutubeService] post failed: #{status_code} - #{err}")
    Messages::StatusUpdateService.new(message, 'failed', "#{status_code} - #{err}").perform
  end

  def handle_error(error)
    ChatwootExceptionTracker.new(error, account: message.account, user: message.sender).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', error.message).perform
  end
end
