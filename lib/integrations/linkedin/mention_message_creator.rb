# frozen_string_literal: true

# Processes LinkedIn organization/member mention notifications and routes
# them to the Mentions sub-inbox. One Chatwoot conversation per origin post URN.
class Integrations::Linkedin::MentionMessageCreator
  def initialize(channel, inbox, event)
    @channel = channel
    @inbox = inbox
    @event = event
  end

  def perform
    return if mention_id.blank?
    return if actor_urn.blank?
    return if duplicate?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def mention_id
    @event['id'] || @event.dig('object', 'id')
  end

  def actor_urn
    @event['actor'] || @event.dig('object', 'actor')
  end

  def post_urn
    @event['object'] || mention_id
  end

  def message_text
    @event.dig('message', 'text') || @event['text'] || @event.dig('object', 'commentary') || ''
  end

  def actor_name
    @event['actor_name'].presence || actor_urn.to_s.split(':').last || 'LinkedIn User'
  end

  def permalink
    @event['permalink'] || @event.dig('object', 'permalink')
  end

  def duplicate?
    Message.exists?(source_id: mention_id, inbox_id: @inbox.id)
  end

  def build_contact_inbox
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: actor_urn,
      inbox: @inbox,
      contact_attributes: { name: actor_name }
    ).perform
  end

  def find_or_create_conversation
    @conversation = Conversation.where(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      identifier: post_urn
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: post_urn,
      additional_attributes: {
        type: 'linkedin_mention',
        post_id: post_urn,
        permalink_url: permalink
      }
    )
  end

  def create_message
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: message_text,
      source_id: mention_id,
      sender: @contact_inbox.contact,
      content_attributes: { type: 'linkedin_mention', post_id: post_urn }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
