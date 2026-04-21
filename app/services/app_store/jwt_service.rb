# Mints an App Store Connect API JWT signed with the channel's .p8 private key (ES256).
# Apple requires a fresh token per call; max lifetime 20 min. We cache for 18 min.
class AppStore::JwtService
  attr_reader :channel

  def initialize(channel:)
    @channel = channel
  end

  def token
    return @cached_token if @cached_token && @cached_expiry && Time.current < @cached_expiry

    fetch!
  end

  private

  def fetch!
    now = Time.current.to_i
    payload = {
      iss: channel.issuer_id,
      iat: now,
      exp: now + (18 * 60),
      aud: 'appstoreconnect-v1'
    }
    headers = { kid: channel.key_id, typ: 'JWT' }

    ec_key = OpenSSL::PKey::EC.new(channel.p8_private_key)
    @cached_token = JWT.encode(payload, ec_key, 'ES256', headers)
    @cached_expiry = 17.minutes.from_now
    @cached_token
  end
end
