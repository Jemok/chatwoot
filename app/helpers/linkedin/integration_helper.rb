module Linkedin::IntegrationHelper
  # MVP scopes — publicly available via "Sign In with LinkedIn using OpenID
  # Connect" + "Share on LinkedIn" products. Org-level scopes
  # (r_organization_social, w_organization_social, rw_organization_admin)
  # require Community Management API approval and will be requested
  # additively once the LINKEDIN_ORG_SCOPES_ENABLED config flips on.
  REQUIRED_SCOPES = %w[
    openid
    profile
    email
    w_member_social
  ].freeze

  def generate_linkedin_token(account_id)
    return if client_secret.blank?

    JWT.encode(token_payload(account_id), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate LinkedIn token: #{e.message}")
    nil
  end

  def token_payload(account_id)
    {
      sub: account_id,
      iat: Time.current.to_i
    }
  end

  def verify_linkedin_token(token)
    return if token.blank? || client_secret.blank?

    decode_token(token, client_secret)
  end

  private

  def client_secret
    @client_secret ||= GlobalConfigService.load('LINKEDIN_APP_SECRET', nil)
  end

  def decode_token(token, secret)
    JWT.decode(token, secret, true, {
                 algorithm: 'HS256',
                 verify_expiration: true
               }).first['sub']
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying LinkedIn token: #{e.message}")
    nil
  end
end
