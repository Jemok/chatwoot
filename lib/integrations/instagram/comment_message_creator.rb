# frozen_string_literal: true

# Processes Instagram `comments` webhook events and creates
# conversations/messages in the Instagram public inbox.
#
# One conversation per (media, commenter) pair — mirrors the Facebook
# feed comment behavior so each customer gets their own thread even
# when multiple people comment on the same post.
#
# Sample change value (comments webhook):
# {
#   "from": { "id": "USER_IG_ID", "username": "jane" },
#   "media": { "id": "MEDIA_ID", "media_product_type": "FEED" },
#   "id": "COMMENT_ID",
#   "parent_id": "PARENT_COMMENT_ID",     # optional (reply-to-comment)
#   "text": "Great post!"
# }
class Integrations::Instagram::CommentMessageCreator
  MEDIA_FIELDS = 'id,caption,media_type,media_url,thumbnail_url,permalink,timestamp'

  def initialize(channel, inbox, change)
    @channel = channel
    @inbox = inbox
    @change = change
  end

  def perform
    return if page_own_comment?
    return if sender_id.blank?
    return if duplicate_message?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def page_own_comment?
    sender_id == @channel.instagram_id
  end

  def duplicate_message?
    Message.exists?(source_id: comment_id, inbox_id: @inbox.id)
  end

  def sender_id
    @change.dig('from', 'id')
  end

  def sender_name
    @change.dig('from', 'username') || 'Instagram User'
  end

  def comment_id
    @change['id']
  end

  def media_id
    @change.dig('media', 'id')
  end

  def parent_id
    @change['parent_id']
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
      identifier: media_id
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    media_data = fetch_media_data || {}
    media_url, post_type = extract_media(media_data)

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: media_id,
      additional_attributes: {
        type: 'instagram_feed',
        post_id: media_id,
        post_content: media_data['caption'],
        post_type: post_type,
        media_url: media_url,
        permalink_url: media_data['permalink']
      }
    )
  end

  def fetch_media_data
    HTTParty.get(
      "https://graph.instagram.com/v22.0/#{media_id}",
      query: { fields: MEDIA_FIELDS, access_token: @channel.access_token }
    ).parsed_response
  rescue StandardError => e
    Rails.logger.warn("[Instagram::CommentMessageCreator] Failed to fetch media #{media_id}: #{e.message}")
    nil
  end

  def extract_media(media_data)
    media_type = media_data['media_type']
    post_type = case media_type
                when 'VIDEO' then 'video'
                when 'IMAGE', 'CAROUSEL_ALBUM' then 'photo'
                else 'status'
                end
    media_url = media_data['media_url'].presence || media_data['thumbnail_url'].presence
    [media_url, post_type]
  end

  def create_message
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: message_text,
      source_id: comment_id,
      sender: @contact_inbox.contact,
      content_attributes: comment_content_attributes
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def comment_content_attributes
    attrs = {
      type: 'instagram_feed_comment',
      comment_id: comment_id,
      post_id: media_id,
      parent_id: parent_id
    }

    if parent_id.present? && parent_id != media_id
      parent_message = @inbox.messages.find_by(source_id: parent_id)
      attrs[:in_reply_to] = parent_message.id if parent_message
      attrs[:in_reply_to_external_id] = parent_id
    end

    attrs
  end
end
