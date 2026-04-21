# frozen_string_literal: true

# Polls App Store Connect for customer reviews on the channel's app.
# GET /v1/apps/{id}/customerReviews?include=response&sort=-createdDate&limit=200
# Each review may include a developer response (one-to-one).
# Conversation grouping: per review id. Source_id dedups review and response separately.
class Integrations::AppStore::ReviewsPoller
  PAGE_SIZE = 200

  def initialize(channel)
    @channel = channel
    @inbox = channel.inbox
  end

  def perform
    return unless @inbox

    body = fetch_reviews
    reviews = Array(body['data'])
    included = Array(body['included'])
    response_lookup = included.each_with_object({}) { |inc, h| h[inc['id']] = inc if inc['type'] == 'customerReviewResponses' }

    reviews.each do |review|
      response_id = review.dig('relationships', 'response', 'data', 'id')
      response = response_lookup[response_id]
      ::Integrations::AppStore::ReviewMessageCreator.new(@channel, @inbox, review, response).perform
    rescue StandardError => e
      Rails.logger.warn("[AppStore::ReviewsPoller] channel=#{@channel.id} review=#{review['id']} #{e.class}: #{e.message}")
    end

    @channel.update_columns(last_polled_at: Time.current)
  end

  private

  def fetch_reviews
    response = HTTParty.get(
      "https://api.appstoreconnect.apple.com/v1/apps/#{CGI.escape(@channel.app_id)}/customerReviews",
      query: { 'include' => 'response', 'sort' => '-createdDate', 'limit' => PAGE_SIZE },
      headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' }
    )

    return JSON.parse(response.body) if response.success?

    Rails.logger.warn("[AppStore::ReviewsPoller] channel=#{@channel.id} HTTP #{response.code}: #{response.body}")
    @channel.authorization_error! if [401, 403].include?(response.code.to_i)
    {}
  rescue StandardError => e
    Rails.logger.warn("[AppStore::ReviewsPoller] channel=#{@channel.id} #{e.class}: #{e.message}")
    {}
  end

  def token
    @token ||= ::AppStore::JwtService.new(channel: @channel).token
  end
end
