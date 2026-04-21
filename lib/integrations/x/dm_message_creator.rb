# frozen_string_literal: true

# Processes incoming X Direct Message events. Conversations are keyed by
# the DM conversation_id (typically `<senderId>-<recipientId>`).
#
# Sample dm shape (Account Activity):
# {
#   "id": "<dm_event_id>",
#   "created_timestamp": "...",
#   "message_create": {
#     "target": { "recipient_id": "<our_id>" },
#     "sender_id": "<sender_id>",
#     "message_data": { "text": "hello" }
#   }
# }
class Integrations::X::DmMessageCreator
  def initialize(channel, inbox, dm, users)
    @channel = channel
    @inbox = inbox
    @dm = dm
    @users = users || {}
  end

  def perform
    return if dm_id.blank?
    return if sender_id.blank?
    return if sender_id.to_s == @channel.x_user_id.to_s
    return if duplicate_message?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def dm_id
    @dm['id'].to_s
  end

  def sender_id
    @dm.dig('message_create', 'sender_id').to_s
  end

  def conversation_key
    [sender_id, @channel.x_user_id.to_s].sort.join('-')
  end

  def sender_user
    @users[sender_id] || {}
  end

  def sender_name
    sender_user['name'] || sender_user['screen_name'] || sender_user['username'] || 'X User'
  end

  def message_text
    @dm.dig('message_create', 'message_data', 'text')
  end

  def duplicate_message?
    Message.exists?(source_id: dm_id, inbox_id: @inbox.id)
  end

  def build_contact_inbox
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: sender_id,
      inbox: @inbox,
      contact_attributes: { name: sender_name }
    ).perform
  end

  def find_or_create_conversation
    @conversation = Conversation.where(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      identifier: conversation_key
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: conversation_key,
      additional_attributes: { type: 'x_direct_message' }
    )
  end

  def create_message
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: message_text,
      source_id: dm_id,
      sender: @contact_inbox.contact,
      content_attributes: { type: 'x_direct_message' }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
