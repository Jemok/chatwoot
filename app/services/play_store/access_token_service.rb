# Mints a Google OAuth access token from a service-account JSON key using
# the JWT bearer flow (RFC 7523). Tokens are cached for ~50 minutes (issued lifetime is 1h).
class PlayStore::AccessTokenService
  attr_reader :channel

  def initialize(channel:)
    @channel = channel
  end

  def access_token
    return @cached_token if @cached_token && @cached_expiry && Time.current < @cached_expiry

    fetch!
  end

  private

  def credentials
    @credentials ||= JSON.parse(channel.credentials_json)
  end

  def fetch!
    response = HTTParty.post(
      'https://oauth2.googleapis.com/token',
      body: {
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: build_assertion
      },
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'Accept' => 'application/json' }
    )
    raise "Play Store token exchange failed: #{response.body}" unless response.success?

    body = JSON.parse(response.body)
    @cached_token = body['access_token']
    @cached_expiry = Time.current + (body['expires_in'].to_i - 60).seconds
    @cached_token
  end

  def build_assertion
    now = Time.current.to_i
    claims = {
      iss: credentials['client_email'],
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: credentials['token_uri'].presence || 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    }
    rsa = OpenSSL::PKey::RSA.new(credentials['private_key'])
    JWT.encode(claims, rsa, 'RS256', { kid: credentials['private_key_id'] })
  end
end
