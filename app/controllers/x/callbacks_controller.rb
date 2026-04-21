class X::CallbacksController < ApplicationController
  include XConcern
  include X::IntegrationHelper

  def show
    if params[:denied].present? || params[:error].present?
      handle_authorization_error
      return
    end

    process_successful_authorization
  rescue StandardError => e
    handle_error(e)
  end

  private

  def process_successful_authorization
    request_secret, account_id = fetch_request_token_context(params[:oauth_token])
    @account_id = account_id
    request_token = ::OAuth::RequestToken.new(x_consumer, params[:oauth_token], request_secret)
    @access_token = request_token.get_access_token(oauth_verifier: params[:oauth_verifier])

    inbox, already_exists = find_or_create_inbox

    if already_exists
      redirect_to app_x_inbox_settings_url(account_id: account_id, inbox_id: inbox.id)
    else
      redirect_to app_x_inbox_agents_url(account_id: account_id, inbox_id: inbox.id)
    end
  end

  def handle_error(error)
    Rails.logger.error("X Channel creation Error: #{error.message}")
    ChatwootExceptionTracker.new(error).capture_exception

    error_info = { 'error_type' => error.class.name, 'code' => 500, 'error_message' => error.message }
    redirect_to_error_page(error_info)
  end

  def handle_authorization_error
    error_info = {
      'error_type' => params[:denied].present? ? 'access_denied' : (params[:error] || 'authorization_error'),
      'code' => 400,
      'error_message' => params[:error_description] || 'Authorization was denied'
    }

    Rails.logger.error("X Authorization Error: #{error_info['error_message']}")
    redirect_to_error_page(error_info)
  end

  def redirect_to_error_page(error_info)
    redirect_to app_new_x_inbox_url(
      account_id: @account_id,
      error_type: error_info['error_type'],
      code: error_info['code'],
      error_message: error_info['error_message']
    )
  end

  def find_or_create_inbox
    x_user_id = @access_token.params[:user_id].to_s
    username = @access_token.params[:screen_name].to_s

    channel_x = Channel::X.find_by(x_user_id: x_user_id, account: account)
    channel_exists = channel_x.present?

    if channel_x
      update_channel(channel_x, username)
    else
      channel_x = create_channel_with_inbox(x_user_id, username)
    end

    channel_x.reauthorized!

    [channel_x.inbox, channel_exists]
  end

  def update_channel(channel_x, username)
    channel_x.update!(
      access_token: @access_token.token,
      access_token_secret: @access_token.secret,
      username: username
    )
    channel_x.inbox.update!(name: username)
    channel_x
  end

  def create_channel_with_inbox(x_user_id, username)
    ActiveRecord::Base.transaction do
      channel_x = Channel::X.create!(
        access_token: @access_token.token,
        access_token_secret: @access_token.secret,
        x_user_id: x_user_id,
        username: username,
        account: account
      )

      account.inboxes.create!(account: account, channel: channel_x, name: username)
      channel_x
    end
  end

  def account
    @account ||= Account.find(@account_id)
  end
end
