class Api::V1::Accounts::Linkedin::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include LinkedinConcern
  include Linkedin::IntegrationHelper

  def create
    redirect_url = linkedin_client.auth_code.authorize_url(
      {
        redirect_uri: "#{base_url}/linkedin/callback",
        scope: REQUIRED_SCOPES.join(' '),
        response_type: 'code',
        state: generate_linkedin_token(Current.account.id)
      }
    )
    if redirect_url
      render json: { success: true, url: redirect_url }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end
end
