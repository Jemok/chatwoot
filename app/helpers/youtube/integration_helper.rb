module Youtube::IntegrationHelper
  REQUIRED_SCOPES = %w[
    https://www.googleapis.com/auth/youtube.force-ssl
    https://www.googleapis.com/auth/youtube.readonly
  ].freeze

  def generate_youtube_token(account_id)
    return if client_secret.blank?

    JWT.encode(token_payload(account_id), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate YouTube token: #{e.message}")
    nil
  end

  def token_payload(account_id)
    { sub: account_id, iat: Time.current.to_i }
  end

  def verify_youtube_token(token)
    return if token.blank? || client_secret.blank?

    decode_token(token, client_secret)
  end

  private

  def client_secret
    @client_secret ||= GlobalConfigService.load('YOUTUBE_CLIENT_SECRET', nil)
  end

  def decode_token(token, secret)
    JWT.decode(token, secret, true, { algorithm: 'HS256', verify_expiration: true }).first['sub']
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying YouTube token: #{e.message}")
    nil
  end
end
