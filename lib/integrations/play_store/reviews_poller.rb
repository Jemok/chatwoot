# frozen_string_literal: true

# Polls Google Play Developer API for new reviews on a given app package.
# GET /androidpublisher/v3/applications/{packageName}/reviews
# Response window: last ~7 days. Each review may have a user comment and an optional developer reply.
# Conversation grouping: per reviewId. Message dedup via composite source_id including comment timestamp.
class Integrations::PlayStore::ReviewsPoller
  PAGE_SIZE = 100

  def initialize(channel)
    @channel = channel
    @inbox = channel.inbox
  end

  def perform
    return unless @inbox

    fetch_reviews.each do |review|
      ::Integrations::PlayStore::ReviewMessageCreator.new(@channel, @inbox, review).perform
    rescue StandardError => e
      Rails.logger.warn("[PlayStore::ReviewsPoller] channel=#{@channel.id} review=#{review['reviewId']} #{e.class}: #{e.message}")
    end

    @channel.update_columns(last_polled_at: Time.current)
  end

  private

  def access_token
    @access_token ||= ::PlayStore::AccessTokenService.new(channel: @channel).access_token
  end

  def fetch_reviews
    response = HTTParty.get(
      "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{CGI.escape(@channel.package_name)}/reviews",
      query: { maxResults: PAGE_SIZE },
      headers: { 'Authorization' => "Bearer #{access_token}", 'Accept' => 'application/json' }
    )

    return Array(JSON.parse(response.body)['reviews']) if response.success?

    Rails.logger.warn("[PlayStore::ReviewsPoller] channel=#{@channel.id} HTTP #{response.code}: #{response.body}")
    @channel.authorization_error! if [401, 403].include?(response.code.to_i)
    []
  rescue StandardError => e
    Rails.logger.warn("[PlayStore::ReviewsPoller] channel=#{@channel.id} #{e.class}: #{e.message}")
    []
  end
end
