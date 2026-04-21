class Api::V1::Accounts::PlayStoreChannelsController < Api::V1::Accounts::BaseController
  def create
    creds_json = read_credentials
    channel = Channel::PlayStoreReviews.create!(
      account: Current.account,
      package_name: permitted_params[:package_name],
      service_account_email: parsed_email(creds_json),
      credentials_json: creds_json
    )
    inbox = Current.account.inboxes.create!(
      account: Current.account,
      channel: channel,
      name: permitted_params[:name].presence || permitted_params[:package_name]
    )
    render json: { id: inbox.id, name: inbox.name, channel_type: 'Channel::PlayStoreReviews' }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  private
  def permitted_params
    params.permit(:package_name, :name, :credentials_json, :credentials_file)
  end
  def read_credentials
    if permitted_params[:credentials_file].present?
      permitted_params[:credentials_file].read
    else
      permitted_params[:credentials_json].to_s
    end
  end
  def parsed_email(json)
    JSON.parse(json)['client_email']
  rescue StandardError
    nil
  end
end
