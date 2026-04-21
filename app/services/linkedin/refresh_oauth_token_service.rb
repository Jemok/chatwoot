# Refreshes LinkedIn 60-day access tokens when within 10 days of expiry.
# Refresh tokens are only issued when the LinkedIn app has the "Refresh
# Tokens" product enabled; otherwise we silently fall back to the stored
# access token and rely on the re-auth email flow at expiry.
class Linkedin::RefreshOauthTokenService
  attr_reader :channel

  def initialize(channel:)
    @channel = channel
  end

  def access_token
    return channel[:access_token] unless eligible_for_refresh?

    attempt_refresh
  end

  private

  def eligible_for_refresh?
    return false if channel.refresh_token.blank?
    return false if channel.expires_at.blank?
    return false if channel.updated_at.blank?

    Time.current < channel.expires_at &&
      Time.current - channel.updated_at >= 24.hours &&
      channel.expires_at < 10.days.from_now
  end

  def refresh_token!
    response = HTTParty.post(
      'https://www.linkedin.com/oauth/v2/accessToken',
      body: {
        grant_type: 'refresh_token',
        refresh_token: channel.refresh_token,
        client_id: GlobalConfigService.load('LINKEDIN_APP_ID', nil),
        client_secret: GlobalConfigService.load('LINKEDIN_APP_SECRET', nil)
      },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'Accept' => 'application/json' }
    )

    raise "LinkedIn token refresh failed: #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  def apply!(data)
    channel.update!(
      access_token: data['access_token'],
      refresh_token: data['refresh_token'].presence || channel.refresh_token,
      expires_at: Time.current + data['expires_in'].to_i.seconds
    )
  end

  def attempt_refresh
    apply!(refresh_token!)
    channel.reload[:access_token]
  rescue StandardError => e
    Rails.logger.warn("[Linkedin::RefreshOauthTokenService] channel=#{channel.id} #{e.class}: #{e.message}")
    channel[:access_token]
  end
end
