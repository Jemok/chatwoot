class Api::V1::Accounts::Youtube::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include YoutubeConcern
  include Youtube::IntegrationHelper

  def create
    redirect_url = youtube_client.auth_code.authorize_url(
      {
        redirect_uri: "#{base_url}/youtube/callback",
        scope: REQUIRED_SCOPES.join(' '),
        response_type: 'code',
        access_type: 'offline',
        prompt: 'consent',
        state: generate_youtube_token(Current.account.id)
      }
    )

    if redirect_url
      render json: { success: true, url: redirect_url }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end
end
