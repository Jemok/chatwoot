class Linkedin::CallbacksController < ApplicationController
  include LinkedinConcern
  include Linkedin::IntegrationHelper

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
    @response = linkedin_client.auth_code.get_token(
      oauth_code,
      redirect_uri: "#{base_url}/#{provider_name}/callback",
      grant_type: 'authorization_code'
    )

    inbox, already_exists = find_or_create_inbox

    if already_exists
      redirect_to app_linkedin_inbox_settings_url(account_id: account_id, inbox_id: inbox.id)
    else
      redirect_to app_linkedin_inbox_agents_url(account_id: account_id, inbox_id: inbox.id)
    end
  end

  def handle_error(error)
    Rails.logger.error("LinkedIn Channel creation Error: #{error.message}")
    ChatwootExceptionTracker.new(error).capture_exception

    error_info = extract_error_info(error)
    redirect_to_error_page(error_info)
  end

  def extract_error_info(error)
    if error.is_a?(OAuth2::Error)
      begin
        JSON.parse(error.message)
      rescue JSON::ParserError
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

    Rails.logger.error("LinkedIn Authorization Error: #{error_info['error_message']}")
    redirect_to_error_page(error_info)
  end

  def redirect_to_error_page(error_info)
    redirect_to app_new_linkedin_inbox_url(
      account_id: account_id,
      error_type: error_info['error_type'],
      code: error_info['code'],
      error_message: error_info['error_message']
    )
  end

  def find_or_create_inbox
    user_details = fetch_linkedin_user_details(@response.token)
    member_urn = "urn:li:person:#{user_details['sub']}"
    channel = find_channel_by_user_urn(member_urn)
    channel_exists = channel.present?

    if channel
      update_channel(channel, user_details)
    else
      channel = create_channel_with_inbox(member_urn, user_details)
    end

    channel.reauthorized!
    [channel.inbox, channel_exists]
  end

  def find_channel_by_user_urn(member_urn)
    Channel::Linkedin.find_by(linkedin_user_urn: member_urn, account: account)
  end

  def update_channel(channel, user_details)
    channel.update!(
      access_token: @response.token,
      refresh_token: @response.refresh_token,
      expires_at: token_expires_at,
      username: display_name(user_details)
    )

    channel.inbox.update!(name: display_name(user_details))
    channel
  end

  def create_channel_with_inbox(member_urn, user_details)
    name = display_name(user_details)

    ActiveRecord::Base.transaction do
      channel = Channel::Linkedin.create!(
        access_token: @response.token,
        refresh_token: @response.refresh_token,
        linkedin_user_urn: member_urn,
        username: name,
        account: account,
        expires_at: token_expires_at
      )

      account.inboxes.create!(
        account: account,
        channel: channel,
        name: name
      )

      channel
    end
  end

  def display_name(user_details)
    user_details['name'].presence || user_details['email'].presence || 'LinkedIn'
  end

  def token_expires_at
    Time.current + (@response.expires_in || 60.days.to_i).to_i.seconds
  end

  def account_id
    return unless params[:state]

    verify_linkedin_token(params[:state])
  end

  def oauth_code
    params[:code]
  end

  def account
    @account ||= Account.find(account_id)
  end

  def provider_name
    'linkedin'
  end
end
