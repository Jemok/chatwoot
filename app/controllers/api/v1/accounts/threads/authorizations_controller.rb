class Api::V1::Accounts::Threads::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include ThreadsConcern
  include Threads::IntegrationHelper

  def create
    redirect_url = threads_client.auth_code.authorize_url(
      {
        redirect_uri: "#{base_url}/threads/callback",
        scope: REQUIRED_SCOPES.join(','),
        response_type: 'code',
        state: generate_threads_token(Current.account.id)
      }
    )
    if redirect_url
      render json: { success: true, url: redirect_url }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end
end
