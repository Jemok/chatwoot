# Posts an App Store Connect customer-review response.
# POST /v1/customerReviewResponses
# body: { data: { type: 'customerReviewResponses',
#                 attributes: { responseBody: <text> },
#                 relationships: { review: { data: { type: 'customerReviews', id: <review_id> } } } } }
class AppStore::SendOnAppStoreService < Base::SendOnChannelService
  private

  def channel_class
    Channel::AppStoreReviews
  end

  def perform_reply
    return if message.content.blank?
    return if review_id.blank?

    response = post_response
    parsed = parse(response)

    if response.success? && parsed.dig('data', 'id').present?
      message.update!(source_id: "as-response-#{parsed.dig('data', 'id')}")
    else
      record_failure(parsed, response.code)
    end
  rescue StandardError => e
    handle_error(e)
  end

  def post_response
    HTTParty.post(
      'https://api.appstoreconnect.apple.com/v1/customerReviewResponses',
      body: payload.to_json,
      headers: {
        'Authorization' => "Bearer #{token}",
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    )
  end

  def payload
    {
      data: {
        type: 'customerReviewResponses',
        attributes: { responseBody: message.outgoing_content },
        relationships: { review: { data: { type: 'customerReviews', id: review_id } } }
      }
    }
  end

  def token
    ::AppStore::JwtService.new(channel: channel).token
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
    err = Array(parsed['errors']).first&.dig('detail') || 'unknown error'
    Rails.logger.error("[AppStore::SendOnAppStoreService] response failed: #{status_code} - #{err}")
    Messages::StatusUpdateService.new(message, 'failed', "#{status_code} - #{err}").perform
  end

  def handle_error(error)
    ChatwootExceptionTracker.new(error, account: message.account, user: message.sender).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', error.message).perform
  end
end
