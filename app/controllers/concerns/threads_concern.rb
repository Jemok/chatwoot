module ThreadsConcern
  extend ActiveSupport::Concern

  def threads_client
    ::OAuth2::Client.new(
      client_id,
      client_secret,
      {
        site: 'https://graph.threads.net',
        authorize_url: 'https://threads.net/oauth/authorize',
        token_url: 'https://graph.threads.net/oauth/access_token',
        auth_scheme: :request_body,
        token_method: :post
      }
    )
  end

  private

  def client_id
    GlobalConfigService.load('THREADS_APP_ID', nil)
  end

  def client_secret
    GlobalConfigService.load('THREADS_APP_SECRET', nil)
  end

  # Long-lived tokens on Threads are valid for ~60 days and obtained
  # by exchanging the short-lived token via the `th_exchange_token`
  # grant on graph.threads.net.
  def exchange_for_long_lived_token(short_lived_token)
    endpoint = 'https://graph.threads.net/access_token'
    params = {
      grant_type: 'th_exchange_token',
      client_secret: client_secret,
      access_token: short_lived_token
    }

    make_api_request(endpoint, params, 'Failed to exchange Threads token')
  end

  def fetch_threads_user_details(access_token)
    endpoint = 'https://graph.threads.net/v1.0/me'
    params = {
      fields: 'id,username,threads_profile_picture_url,threads_biography',
      access_token: access_token
    }

    make_api_request(endpoint, params, 'Failed to fetch Threads user details')
  end

  def make_api_request(endpoint, params, error_prefix)
    response = HTTParty.get(
      endpoint,
      query: params,
      headers: { 'Accept' => 'application/json' }
    )

    unless response.success?
      Rails.logger.error "#{error_prefix}. Status: #{response.code}, Body: #{response.body}"
      raise "#{error_prefix}: #{response.body}"
    end

    begin
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      ChatwootExceptionTracker.new(e).capture_exception
      Rails.logger.error "Invalid JSON response: #{response.body}"
      raise e
    end
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
