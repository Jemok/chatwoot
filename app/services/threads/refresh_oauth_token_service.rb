# Service to handle Threads access token refresh.
# Threads long-lived tokens are valid for 60 days and can be refreshed.
# https://developers.facebook.com/docs/threads/get-started/long-lived-tokens
class Threads::RefreshOauthTokenService
  attr_reader :channel

  def initialize(channel:)
    @channel = channel
  end

  def access_token
    return unless token_valid?
    return channel[:access_token] unless token_eligible_for_refresh?

    attempt_token_refresh
  end

  private

  def token_valid?
    return false if channel.expires_at.blank?

    Time.current < channel.expires_at
  end

  def token_eligible_for_refresh?
    token_is_valid = Time.current < channel.expires_at
    token_is_old_enough = channel.updated_at.present? && Time.current - channel.updated_at >= 24.hours
    approaching_expiry = channel.expires_at < 10.days.from_now

    token_is_valid && token_is_old_enough && approaching_expiry
  end

  def refresh_long_lived_token
    endpoint = 'https://graph.threads.net/refresh_access_token'
    params = {
      grant_type: 'th_refresh_token',
      access_token: channel[:access_token]
    }

    response = HTTParty.get(endpoint, query: params, headers: { 'Accept' => 'application/json' })

    unless response.success?
      Rails.logger.error "Failed to refresh Threads token: #{response.body}"
      raise "Failed to refresh Threads token: #{response.body}"
    end

    JSON.parse(response.body)
  end

  def update_channel_tokens(token_data)
    channel.update!(
      access_token: token_data['access_token'],
      expires_at: Time.current + token_data['expires_in'].seconds
    )
  end

  def attempt_token_refresh
    refreshed_token_data = refresh_long_lived_token
    update_channel_tokens(refreshed_token_data)
    channel.reload[:access_token]
  rescue StandardError => e
    Rails.logger.error("Threads token refresh failed: #{e.message}")
    channel[:access_token]
  end
end
