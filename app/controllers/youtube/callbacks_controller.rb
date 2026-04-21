class Youtube::CallbacksController < ApplicationController
  include YoutubeConcern
  include Youtube::IntegrationHelper

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
    @response = youtube_client.auth_code.get_token(
      oauth_code,
      redirect_uri: "#{base_url}/youtube/callback",
      grant_type: 'authorization_code'
    )

    inbox, already_exists = find_or_create_inbox

    if already_exists
      redirect_to app_youtube_inbox_settings_url(account_id: account_id, inbox_id: inbox.id)
    else
      redirect_to app_youtube_inbox_agents_url(account_id: account_id, inbox_id: inbox.id)
    end
  end

  def handle_error(error)
    Rails.logger.error("YouTube Channel creation Error: #{error.message}")
    ChatwootExceptionTracker.new(error).capture_exception
    redirect_to_error_page('error_type' => error.class.name, 'code' => 500, 'error_message' => error.message)
  end

  def handle_authorization_error
    redirect_to_error_page(
      'error_type' => params[:error] || 'authorization_error',
      'code' => 400,
      'error_message' => params[:error_description] || 'Authorization was denied'
    )
  end

  def redirect_to_error_page(error_info)
    redirect_to app_new_youtube_inbox_url(
      account_id: account_id,
      error_type: error_info['error_type'],
      code: error_info['code'],
      error_message: error_info['error_message']
    )
  end

  def find_or_create_inbox
    yt_channel = fetch_youtube_channel(@response.token)
    youtube_channel_id = yt_channel['id']
    title = yt_channel.dig('snippet', 'title') || 'YouTube'

    channel = Channel::Youtube.find_by(youtube_channel_id: youtube_channel_id, account: account)
    channel_exists = channel.present?

    if channel
      channel.update!(
        access_token: @response.token,
        refresh_token: @response.refresh_token.presence || channel.refresh_token,
        expires_at: token_expires_at,
        channel_title: title
      )
      channel.inbox.update!(name: title)
    else
      ActiveRecord::Base.transaction do
        channel = Channel::Youtube.create!(
          access_token: @response.token,
          refresh_token: @response.refresh_token,
          expires_at: token_expires_at,
          youtube_channel_id: youtube_channel_id,
          channel_title: title,
          account: account
        )
        account.inboxes.create!(account: account, channel: channel, name: title)
      end
    end

    channel.reauthorized!
    [channel.inbox, channel_exists]
  end

  def token_expires_at
    Time.current + (@response.expires_in || 1.hour.to_i).to_i.seconds
  end

  def account_id
    return unless params[:state]

    verify_youtube_token(params[:state])
  end

  def oauth_code
    params[:code]
  end

  def account
    @account ||= Account.find(account_id)
  end
end
