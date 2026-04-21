module YoutubeConcern
  extend ActiveSupport::Concern

  def youtube_client
    ::OAuth2::Client.new(
      client_id,
      client_secret,
      {
        site: 'https://oauth2.googleapis.com',
        authorize_url: 'https://accounts.google.com/o/oauth2/v2/auth',
        token_url: 'https://oauth2.googleapis.com/token',
        auth_scheme: :request_body,
        token_method: :post
      }
    )
  end

  private

  def client_id
    GlobalConfigService.load('YOUTUBE_CLIENT_ID', nil)
  end

  def client_secret
    GlobalConfigService.load('YOUTUBE_CLIENT_SECRET', nil)
  end

  # GET /youtube/v3/channels?part=snippet&mine=true
  def fetch_youtube_channel(access_token)
    response = HTTParty.get(
      'https://www.googleapis.com/youtube/v3/channels',
      query: { part: 'snippet', mine: 'true' },
      headers: {
        'Authorization' => "Bearer #{access_token}",
        'Accept' => 'application/json'
      }
    )

    raise "YouTube API error #{response.code}: #{response.body}" unless response.success?

    parsed = JSON.parse(response.body)
    parsed['items']&.first || raise('No YouTube channel returned for the authenticated user')
  end

  def base_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
  end
end
