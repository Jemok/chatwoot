# Refreshes YouTube/Google OAuth access tokens (1h expiry) using the
# long-lived refresh token issued at consent (access_type=offline, prompt=consent).
class Youtube::RefreshOauthTokenService
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

    channel.expires_at < 2.minutes.from_now
  end

  def refresh!
    response = HTTParty.post(
      'https://oauth2.googleapis.com/token',
      body: {
        grant_type: 'refresh_token',
        refresh_token: channel.refresh_token,
        client_id: GlobalConfigService.load('YOUTUBE_CLIENT_ID', nil),
        client_secret: GlobalConfigService.load('YOUTUBE_CLIENT_SECRET', nil)
      },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'Accept' => 'application/json' }
    )
    raise "YouTube token refresh failed: #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  def apply!(data)
    channel.update!(
      access_token: data['access_token'],
      expires_at: Time.current + data['expires_in'].to_i.seconds
    )
  end

  def attempt_refresh
    apply!(refresh!)
    channel.reload[:access_token]
  rescue StandardError => e
    Rails.logger.warn("[Youtube::RefreshOauthTokenService] channel=#{channel.id} #{e.class}: #{e.message}")
    channel.authorization_error!
    channel[:access_token]
  end
end
