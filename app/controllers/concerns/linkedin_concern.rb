module LinkedinConcern
  extend ActiveSupport::Concern

  def linkedin_client
    ::OAuth2::Client.new(
      client_id,
      client_secret,
      {
        site: 'https://api.linkedin.com',
        authorize_url: 'https://www.linkedin.com/oauth/v2/authorization',
        token_url: 'https://www.linkedin.com/oauth/v2/accessToken',
        auth_scheme: :request_body,
        token_method: :post
      }
    )
  end

  private

  def client_id
    GlobalConfigService.load('LINKEDIN_APP_ID', nil)
  end

  def client_secret
    GlobalConfigService.load('LINKEDIN_APP_SECRET', nil)
  end

  # OIDC userinfo endpoint — returns sub (member id), name, email, picture
  # when `openid profile email` scopes are granted.
  def fetch_linkedin_user_details(access_token)
    make_api_request(
      'https://api.linkedin.com/v2/userinfo',
      {},
      access_token,
      'Failed to fetch LinkedIn user details'
    )
  end

  def make_api_request(endpoint, query, access_token, error_prefix)
    response = HTTParty.get(
      endpoint,
      query: query,
      headers: {
        'Authorization' => "Bearer #{access_token}",
        'Accept' => 'application/json',
        'LinkedIn-Version' => GlobalConfigService.load('LINKEDIN_API_VERSION', '202604'),
        'X-Restli-Protocol-Version' => '2.0.0'
      }
    )

    unless response.success?
      Rails.logger.error "#{error_prefix}. Status: #{response.code}, Body: #{response.body}"
      raise "#{error_prefix}: #{response.body}"
    end

    JSON.parse(response.body)
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
