# frozen_string_literal: true

# Processes a LinkedIn comment (from webhook event or comments poller) and
# threads it under one Chatwoot conversation per LinkedIn post URN.
#
# Expected event/normalized hash:
# {
#   'id'         => 'urn:li:comment:(urn:li:share:123,456)',
#   'actor'      => 'urn:li:person:abc',
#   'object'     => 'urn:li:share:123',          # parent post URN
#   'message'    => { 'text' => 'Nice post!' },
#   'created'    => { 'time' => 1700000000 },
#   'parentComment' => 'urn:li:comment:(urn:li:share:123,222)',  # optional
#   'actor_name' => 'Resolved Name'              # injected by poller
# }
class Integrations::Linkedin::CommentMessageCreator
  def initialize(channel, inbox, event)
    @channel = channel
    @inbox = inbox
    @event = event
  end

  def perform
    return if comment_id.blank?
    return if actor_urn.blank?
    return if actor_urn == channel_actor_urn
    return if duplicate?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def comment_id
    @event['id']
  end

  def actor_urn
    @event['actor']
  end

  def channel_actor_urn
    @channel.organization_urn.presence || @channel.linkedin_user_urn
  end

  def post_urn
    @event['object'] || @event.dig('parentComment', 'object') || comment_id
  end

  def parent_comment_urn
    @event['parentComment']
  end

  def message_text
    @event.dig('message', 'text') || @event['text'] || ''
  end

  def actor_name
    @event['actor_name'].presence || actor_urn.to_s.split(':').last || 'LinkedIn User'
  end

  def duplicate?
    Message.exists?(source_id: comment_id, inbox_id: @inbox.id)
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
        type: 'linkedin_comment',
        post_id: post_urn
      }
    )
  end

  def create_message
    attrs = { type: 'linkedin_comment', post_id: post_urn }

    if parent_comment_urn.present? && parent_comment_urn != comment_id
      parent = @inbox.messages.find_by(source_id: parent_comment_urn)
      attrs[:in_reply_to] = parent.id if parent
      attrs[:in_reply_to_external_id] = parent_comment_urn
    end

    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: message_text,
      source_id: comment_id,
      sender: @contact_inbox.contact,
      content_attributes: attrs
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
