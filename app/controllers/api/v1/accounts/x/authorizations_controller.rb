class Api::V1::Accounts::X::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include XConcern
  include X::IntegrationHelper

  def create
    request_token = x_consumer.get_request_token(oauth_callback: "#{base_url}/x/callback")
    store_request_token_context(request_token.token, request_token.secret, Current.account.id)

    render json: { success: true, url: request_token.authorize_url }
  rescue OAuth::Unauthorized, OAuth::Error => e
    Rails.logger.error("[X::Authorization] request_token failed: #{e.class}: #{e.message}")
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end
end
