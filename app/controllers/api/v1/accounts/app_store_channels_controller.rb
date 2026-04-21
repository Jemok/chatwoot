class Api::V1::Accounts::AppStoreChannelsController < Api::V1::Accounts::BaseController
  def create
    channel = Channel::AppStoreReviews.create!(
      account: Current.account,
      app_id: permitted_params[:app_id],
      issuer_id: permitted_params[:issuer_id],
      key_id: permitted_params[:key_id],
      p8_private_key: read_p8,
      vendor_name: permitted_params[:vendor_name]
    )

    inbox = Current.account.inboxes.create!(
      account: Current.account,
      channel: channel,
      name: permitted_params[:name].presence || permitted_params[:vendor_name].presence || permitted_params[:app_id]
    )

    render json: { id: inbox.id, name: inbox.name, channel_type: 'Channel::AppStoreReviews' }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def permitted_params
    params.permit(:app_id, :issuer_id, :key_id, :vendor_name, :name, :p8_private_key, :p8_file)
  end

  def read_p8
    if permitted_params[:p8_file].present?
      permitted_params[:p8_file].read
    else
      permitted_params[:p8_private_key].to_s
    end
  end
end
