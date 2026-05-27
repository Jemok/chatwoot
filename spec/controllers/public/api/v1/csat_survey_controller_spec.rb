require 'rails_helper'

RSpec.describe 'Public Survey Responses API', type: :request do
  describe 'GET public/api/v1/csat_survey/{uuid}' do
    it 'return the csat response for that conversation' do
      conversation = create(:conversation)
      create(:message, conversation: conversation, content_type: 'input_csat')
      get "/public/api/v1/csat_survey/#{conversation.uuid}"
      data = response.parsed_body
      expect(response).to have_http_status(:success)
      expect(data['conversation_id']).to eq conversation.id
    end

    it 'returns not found error for the open conversation' do
      conversation = create(:conversation)
      create(:message, conversation: conversation, content_type: 'text')
      get "/public/api/v1/csat_survey/#{conversation.uuid}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PUT public/api/v1/csat_survey/{uuid}' do
    params = { message: { submitted_values: { csat_survey_response: { rating: 4, feedback_message: 'amazing experience' } } } }
    it 'update csat survey response for the conversation' do
      conversation = create(:conversation)
      message = create(:message, conversation: conversation, content_type: 'input_csat')
      # since csat survey is created in async job, we are mocking the creation.
      create(:csat_survey_response, conversation: conversation, message: message, rating: 4, feedback_message: 'amazing experience')
      patch "/public/api/v1/csat_survey/#{conversation.uuid}",
            params: params,
            as: :json
      expect(response).to have_http_status(:success)
      data = response.parsed_body
      expect(data['conversation_id']).to eq conversation.id
      expect(data['csat_survey_response']['conversation_id']).to eq conversation.id
      expect(data['csat_survey_response']['feedback_message']).to eq 'amazing experience'
      expect(data['csat_survey_response']['rating']).to eq 4
    end

    it 'updates the latest CSAT survey response when multiple surveys exist for the conversation' do
      conversation = create(:conversation)
      create(:message, conversation: conversation, content_type: 'input_csat', created_at: 2.days.ago)
      latest_message = create(:message, conversation: conversation, content_type: 'input_csat', created_at: 1.day.ago)
      create(:csat_survey_response, conversation: conversation, message: latest_message, rating: 4, feedback_message: 'amazing experience')

      patch "/public/api/v1/csat_survey/#{conversation.uuid}",
            params: params,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['id']).to eq latest_message.id
    end

    it 'creates an NPS response from the public survey form' do
      conversation = create(:conversation)
      message = create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox, content_type: 'input_csat')
      payload = {
        message: {
          submitted_values: {
            csat_survey_response: { rating: 4, feedback_message: 'amazing experience' },
            nps_response: { score: 10, comment: 'Very likely' }
          }
        }
      }

      expect do
        patch "/public/api/v1/csat_survey/#{conversation.uuid}",
              params: payload,
              as: :json
      end.to change(NpsResponse, :count).by(1)

      nps_response = NpsResponse.last
      expect(response).to have_http_status(:success)
      expect(nps_response.score).to eq 10
      expect(nps_response.comment).to eq 'Very likely'
      expect(nps_response.contact).to eq conversation.contact
      expect(response.parsed_body['nps_response']['id']).to eq nps_response.id
      expect(message.reload.content_attributes.dig('submitted_values', 'nps_response')).to include(
        'id' => nps_response.id,
        'score' => 10,
        'comment' => 'Very likely'
      )
    end

    it 'returns update error if CSAT message sent more than 14 days' do
      conversation = create(:conversation)
      message = create(:message, conversation: conversation, content_type: 'input_csat', created_at: 15.days.ago)
      create(:csat_survey_response, conversation: conversation, message: message, rating: 4, feedback_message: 'amazing experience')
      patch "/public/api/v1/csat_survey/#{conversation.uuid}",
            params: params,
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
