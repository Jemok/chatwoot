# Replies to a Play Store review via:
# POST /androidpublisher/v3/applications/{packageName}/reviews/{reviewId}:reply
# body: { replyText: "..." }
# Reply window: 7 days from the user's review (Google API will 400 outside that).
class PlayStore::SendOnPlayStoreService < Base::SendOnChannelService
  private

  def channel_class
    Channel::PlayStoreReviews
  end

  def perform_reply
    return if message.content.blank?
    return if review_id.blank?

    response = post_reply
    parsed = parse(response)

    if response.success?
      message.update!(source_id: "ps-reply-#{message.id}")
    else
      record_failure(parsed, response.code)
    end
  rescue StandardError => e
    handle_error(e)
  end

  def post_reply
    HTTParty.post(
      "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{CGI.escape(channel.package_name)}/reviews/#{CGI.escape(review_id)}:reply",
      body: { replyText: message.outgoing_content }.to_json,
      headers: {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    )
  end

  def access_token
    ::PlayStore::AccessTokenService.new(channel: channel).access_token
  end

  def review_id
    conversation.identifier
  end

  def parse(response)
    JSON.parse(response.body)
  rescue StandardError
    {}
  end

  def record_failure(parsed, status_code)
    channel.authorization_error! if [401, 403].include?(status_code.to_i)
    err = parsed.dig('error', 'message') || 'unknown error'
    Rails.logger.error("[PlayStore::SendOnPlayStoreService] reply failed: #{status_code} - #{err}")
    Messages::StatusUpdateService.new(message, 'failed', "#{status_code} - #{err}").perform
  end

  def handle_error(error)
    ChatwootExceptionTracker.new(error, account: message.account, user: message.sender).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', error.message).perform
  end
end
