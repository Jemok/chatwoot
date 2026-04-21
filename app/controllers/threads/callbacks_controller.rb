class Threads::CallbacksController < ApplicationController
  include ThreadsConcern
  include Threads::IntegrationHelper

  def show
    if params[:error].present?
      handle_authorization_error
      return
    end

    process_successful_authorization
  rescue StandardError => e
    handle_error(e)
  end

  private

  def process_successful_authorization
    @response = threads_client.auth_code.get_token(
      oauth_code,
      redirect_uri: "#{base_url}/#{provider_name}/callback",
      grant_type: 'authorization_code'
    )

    @long_lived_token_response = exchange_for_long_lived_token(@response.token)
    inbox, already_exists = find_or_create_inbox

    if already_exists
      redirect_to app_threads_inbox_settings_url(account_id: account_id, inbox_id: inbox.id)
    else
      redirect_to app_threads_inbox_agents_url(account_id: account_id, inbox_id: inbox.id)
    end
  end

  def handle_error(error)
    Rails.logger.error("Threads Channel creation Error: #{error.message}")
    ChatwootExceptionTracker.new(error).capture_exception

    error_info = extract_error_info(error)
    redirect_to_error_page(error_info)
  end

  def extract_error_info(error)
    if error.is_a?(OAuth2::Error)
      begin
        JSON.parse(error.message)
      rescue JSON::ParseError
        { 'error_type' => 'OAuthException', 'code' => 400, 'error_message' => error.message }
      end
    else
      { 'error_type' => error.class.name, 'code' => 500, 'error_message' => error.message }
    end
  end

  def handle_authorization_error
    error_info = {
      'error_type' => params[:error] || 'authorization_error',
      'code' => 400,
      'error_message' => params[:error_description] || 'Authorization was denied'
    }

    Rails.logger.error("Threads Authorization Error: #{error_info['error_message']}")
    redirect_to_error_page(error_info)
  end

  def redirect_to_error_page(error_info)
    redirect_to app_new_threads_inbox_url(
      account_id: account_id,
      error_type: error_info['error_type'],
      code: error_info['code'],
      error_message: error_info['error_message']
    )
  end

  def find_or_create_inbox
    user_details = fetch_threads_user_details(@long_lived_token_response['access_token'])
    channel_threads = find_channel_by_threads_user_id(user_details['id'].to_s)
    channel_exists = channel_threads.present?

    if channel_threads
      update_channel(channel_threads, user_details)
    else
      channel_threads = create_channel_with_inbox(user_details)
    end

    channel_threads.reauthorized!

    [channel_threads.inbox, channel_exists]
  end

  def find_channel_by_threads_user_id(threads_user_id)
    Channel::Threads.find_by(threads_user_id: threads_user_id, account: account)
  end

  def update_channel(channel_threads, user_details)
    expires_at = Time.current + @long_lived_token_response['expires_in'].seconds

    channel_threads.update!(
      access_token: @long_lived_token_response['access_token'],
      expires_at: expires_at,
      username: user_details['username']
    )

    channel_threads.inbox.update!(name: user_details['username'])
    channel_threads
  end

  def create_channel_with_inbox(user_details)
    ActiveRecord::Base.transaction do
      expires_at = Time.current + @long_lived_token_response['expires_in'].seconds

      channel_threads = Channel::Threads.create!(
        access_token: @long_lived_token_response['access_token'],
        threads_user_id: user_details['id'].to_s,
        username: user_details['username'],
        account: account,
        expires_at: expires_at
      )

      account.inboxes.create!(
        account: account,
        channel: channel_threads,
        name: user_details['username']
      )

      channel_threads
    end
  end

  def account_id
    return unless params[:state]

    verify_threads_token(params[:state])
  end

  def oauth_code
    params[:code]
  end

  def account
    @account ||= Account.find(account_id)
  end

  def provider_name
    'threads'
  end
end
