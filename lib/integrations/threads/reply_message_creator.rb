# frozen_string_literal: true

# Processes Threads `replies` webhook events — replies on our own threads.
# One conversation per (root_post, replier) pair.
#
# Sample change value:
# {
#   "id": "<REPLY_ID>",
#   "text": "Nice thread!",
#   "media_type": "TEXT_POST",
#   "permalink": "https://www.threads.net/...",
#   "timestamp": "2026-04-17T...",
#   "username": "replier_username",
#   "from": { "id": "<REPLIER_THREADS_USER_ID>", "username": "replier_username" },
#   "root_post": { "id": "<ROOT_THREAD_ID>" },
#   "replied_to": { "id": "<PARENT_REPLY_OR_ROOT_ID>" }
# }
class Integrations::Threads::ReplyMessageCreator
  ROOT_FIELDS = 'id,text,media_type,media_url,thumbnail_url,permalink,timestamp'

  def initialize(channel, inbox, change)
    @channel = channel
    @inbox = inbox
    @change = change
  end

  def perform
    return if own_reply?
    return if sender_id.blank?
    return if duplicate_message?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def own_reply?
    sender_id == @channel.threads_user_id ||
      (@channel.username.present? && @change['username'].to_s.casecmp(@channel.username.to_s).zero?)
  end

  def duplicate_message?
    Message.exists?(source_id: reply_id, inbox_id: @inbox.id)
  end

  def reply_id
    @change['id']
  end

  def sender_id
    @change.dig('from', 'id') || @change['username']
  end

  def sender_name
    @change.dig('from', 'username') || @change['username'] || 'Threads User'
  end

  def root_post_id
    @change.dig('root_post', 'id') || reply_id
  end

  def parent_id
    @change.dig('replied_to', 'id')
  end

  def message_text
    @change['text']
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
      identifier: root_post_id
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    root = fetch_root_post || {}
    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: root_post_id,
      additional_attributes: {
        type: 'threads_feed',
        post_id: root_post_id,
        post_content: root['text'],
        post_type: post_type_for(root['media_type']),
        media_url: root['media_url'] || root['thumbnail_url'],
        permalink_url: root['permalink']
      }
    )
  end

  def fetch_root_post
    HTTParty.get(
      "https://graph.threads.net/v1.0/#{root_post_id}",
      query: { fields: ROOT_FIELDS, access_token: @channel.access_token }
    ).parsed_response
  rescue StandardError => e
    Rails.logger.warn("[Threads::ReplyMessageCreator] Failed to fetch root post #{root_post_id}: #{e.message}")
    nil
  end

  def post_type_for(media_type)
    case media_type
    when 'VIDEO' then 'video'
    when 'IMAGE', 'CAROUSEL_ALBUM' then 'photo'
    else 'status'
    end
  end

  def create_message
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: message_text,
      source_id: reply_id,
      sender: @contact_inbox.contact,
      content_attributes: reply_content_attributes
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def reply_content_attributes
    attrs = {
      type: 'threads_reply',
      reply_id: reply_id,
      post_id: root_post_id,
      parent_id: parent_id
    }

    if parent_id.present? && parent_id != root_post_id
      parent_message = @inbox.messages.find_by(source_id: parent_id)
      attrs[:in_reply_to] = parent_message.id if parent_message
      attrs[:in_reply_to_external_id] = parent_id
    end

    attrs
  end
end
