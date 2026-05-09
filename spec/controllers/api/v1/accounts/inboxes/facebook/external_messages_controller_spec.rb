require 'rails_helper'

RSpec.describe 'Facebook External Messages API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel) { create(:channel_facebook_page, account: account) }
  let(:inbox) { channel.inbox.tap { |i| i.update!(account: account, queue_kind: 'dm') } }

  before do
    allow_any_instance_of(Channel::FacebookPage).to receive(:subscribe).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  describe 'POST /api/v1/accounts/{account_id}/inboxes/{id}/ingest_messenger_ai_message_by_external_user' do
    let(:path) { "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/ingest_messenger_ai_message_by_external_user" }

    it 'creates contact, conversation and message using external_user_id' do
      post path,
           headers: admin.create_new_auth_token,
           params: {
             message: {
               external_user_id: 'fb-user-123',
               external_user_name: 'External User',
               content: 'AI relay reply',
               source_id: 'relay-1',
               relay_source: 'voice-bot'
             }
           },
           as: :json

      expect(response).to have_http_status(:created)

      payload = JSON.parse(response.body)
      expect(payload['sender_type']).to eq('AgentBot')
      expect(payload.dig('content_attributes', 'external_echo')).to eq(true)
      expect(payload.dig('content_attributes', 'ai_generated')).to eq(true)

      contact_inbox = inbox.contact_inboxes.find_by(source_id: 'fb-user-123')
      expect(contact_inbox).to be_present

      conversation = inbox.conversations.find(payload['conversation_id'])
      expect(conversation.contact_id).to eq(contact_inbox.contact_id)
    end

    it 'returns existing message for duplicate source_id in the same conversation' do
      post path,
           headers: admin.create_new_auth_token,
           params: {
             message: {
               external_user_id: 'fb-user-dup',
               content: 'AI relay reply',
               source_id: 'relay-dup'
             }
           },
           as: :json

      expect(response).to have_http_status(:created)
      first_payload = JSON.parse(response.body)

      post path,
           headers: admin.create_new_auth_token,
           params: {
             message: {
               external_user_id: 'fb-user-dup',
               content: 'AI relay reply updated',
               source_id: 'relay-dup'
             }
           },
           as: :json

      expect(response).to have_http_status(:ok)
      second_payload = JSON.parse(response.body)
      expect(second_payload['id']).to eq(first_payload['id'])
    end

    it 'creates a new messenger conversation when only instagram_direct_message exists for the contact' do
      contact = create(:contact, account: account)
      contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: 'fb-user-ig-only')
      create(:conversation,
             account: account,
             inbox: inbox,
             contact: contact,
             contact_inbox: contact_inbox,
             additional_attributes: { type: 'instagram_direct_message' })

      post path,
           headers: admin.create_new_auth_token,
           params: {
             message: {
               external_user_id: 'fb-user-ig-only',
               content: 'AI relay reply',
               source_id: 'relay-ig-filter'
             }
           },
           as: :json

      expect(response).to have_http_status(:created)
      payload = JSON.parse(response.body)
      conversation = inbox.conversations.find(payload['conversation_id'])
      expect(conversation.additional_attributes['type']).not_to eq('instagram_direct_message')
    end
  end

  describe 'cross-channel support for the external-user ingest endpoint' do
    it 'creates an AI message for an Instagram inbox' do
      instagram_channel = create(:channel_instagram, account: account)
      instagram_inbox = instagram_channel.inbox
      path = "/api/v1/accounts/#{account.id}/inboxes/#{instagram_inbox.id}/ingest_messenger_ai_message_by_external_user"

      post path,
           headers: admin.create_new_auth_token,
           params: {
             message: {
               external_user_id: 'ig-user-1',
               content: 'IG AI relay reply',
               source_id: 'relay-ig-1'
             }
           },
           as: :json

      expect(response).to have_http_status(:created)
      payload = JSON.parse(response.body)
      expect(payload['sender_type']).to eq('AgentBot')
      expect(payload.dig('content_attributes', 'external_echo')).to eq(true)
    end

    it 'creates an AI message for a WhatsApp inbox' do
      whatsapp_channel = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false)
      whatsapp_inbox = whatsapp_channel.inbox
      path = "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/ingest_messenger_ai_message_by_external_user"

      post path,
           headers: admin.create_new_auth_token,
           params: {
             message: {
               external_user_id: '1234567890',
               content: 'WA AI relay reply',
               source_id: 'relay-wa-1'
             }
           },
           as: :json

      expect(response).to have_http_status(:created)
      payload = JSON.parse(response.body)
      expect(payload['sender_type']).to eq('AgentBot')
      expect(payload.dig('content_attributes', 'ai_generated')).to eq(true)
    end
  end
end
