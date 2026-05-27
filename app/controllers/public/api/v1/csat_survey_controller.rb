class Public::Api::V1::CsatSurveyController < PublicController
  before_action :set_conversation
  before_action :set_message

  def show; end

  def update
    render json: { error: 'You cannot update the CSAT survey after 14 days' }, status: :unprocessable_entity and return if check_csat_locked

    @message.update!(message_payload)
    create_nps_response
  end

  private

  def set_conversation
    return if params[:id].blank?

    @conversation = Conversation.find_by!(uuid: params[:id])
  end

  def set_message
    @message = @conversation.messages.where(content_type: 'input_csat').reorder(id: :desc).first!
  end

  def message_update_params
    params.permit(
      message: [
        {
          submitted_values: [
            :name, :title, :value,
            { csat_survey_response: [:feedback_message, :rating], nps_response: [:id, :score, :comment] }
          ]
        }
      ]
    )
  end

  def message_payload
    @message_payload ||= message_update_params[:message]
  end

  def create_nps_response
    payload = message_payload.dig(:submitted_values, :nps_response)
    return if payload.blank? || payload[:score].blank? || payload[:id].present?

    response = NpsResponse.create!(
      account: @message.account,
      contact: @conversation.contact,
      conversation: @conversation,
      inbox: @message.inbox,
      score: payload[:score],
      comment: payload[:comment]
    )
    store_nps_response_id(response.id)
  end

  def store_nps_response_id(response_id)
    attributes = @message.content_attributes.deep_dup
    attributes['submitted_values']['nps_response']['id'] = response_id
    @message.update!(content_attributes: attributes)
  end

  def check_csat_locked
    (Time.zone.now.to_date - @message.created_at.to_date).to_i > 14
  end
end
