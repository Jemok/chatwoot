# frozen_string_literal: true

# Processes Threads `mentions` and `quotes` webhook events — when someone
# @-mentions our account in their own thread or quotes one of our threads.
# Also used by the mentions poller as a unified ingest path.
#
# Sample change value (mentions):
# {
#   "id": "<MENTION_THREAD_ID>",
#   "text": "@simplify_orders check this out",
#   "media_type": "TEXT_POST",
#   "permalink": "https://www.threads.net/...",
#   "timestamp": "2026-04-17T...",
#   "username": "mentioner_username",
#   "from": { "id": "<MENTIONER_THREADS_USER_ID>", "username": "mentioner_username" }
# }
class Integrations::Threads::MentionMessageCreator
  # :field is 'mentions' or 'quotes' — controls conversation/message typing.
  def initialize(channel, inbox, change, field: 'mentions')
    @channel = channel
    @inbox = inbox
    @change = change
    @field = field.to_s
  end

  def perform
    return if mention_id.blank?
    return if duplicate_message?

    # Threads does not always expose owner.id for content owned by other accounts;
    # fall back to username as the stable per-contact source_id.
    @sender_id = @change.dig('from', 'id').presence || @change['username'].presence
    return if @sender_id.blank?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def mention_id
    @change['id']
  end

  def sender_name
    @change.dig('from', 'username') || @change['username'] || 'Threads User'
  end

  def message_text
    @change['text']
  end

  def permalink
    @change['permalink']
  end

  def media_type
    @change['media_type']
  end

  def quote?
    @field == 'quotes'
  end

  def duplicate_message?
    Message.exists?(source_id: mention_id, inbox_id: @inbox.id)
  end

  def post_type_for(type)
    case type
    when 'VIDEO' then 'video'
    when 'IMAGE', 'CAROUSEL_ALBUM' then 'photo'
    else 'status'
    end
  end

  def build_contact_inbox
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: @sender_id,
      inbox: @inbox,
      contact_attributes: { name: sender_name }
    ).perform
  end

  def find_or_create_conversation
    @conversation = Conversation.where(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      identifier: mention_id
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: mention_id,
      additional_attributes: {
        type: 'threads_feed',
        post_id: mention_id,
        post_content: message_text,
        post_type: post_type_for(media_type),
        media_url: @change['media_url'] || @change['thumbnail_url'],
        is_mention: !quote?,
        is_quote: quote?,
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
      content_attributes: {
        type: quote? ? 'threads_quote' : 'threads_mention',
        post_id: mention_id
      }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
