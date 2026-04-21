# frozen_string_literal: true

# Processes Facebook 'mention' webhook events — created when the page is
# tagged in someone else's post or comment.
#
# One conversation per mention context (post_id). Post and comment mentions
# on the same post group together.
#
# Sample payload (post mention):
# {
#   "sender_id": "USER_ID", "sender_name": "Jane",
#   "item": "post", "post_id": "PAGE_POSTID",
#   "message": "@YourPage ...", "permalink_url": "...",
#   "verb": "add", "created_time": 1700000000
# }
#
# Sample payload (comment mention):
# {
#   "sender_id": "USER_ID", "sender_name": "Jane",
#   "item": "comment", "post_id": "...", "comment_id": "...",
#   "message": "@YourPage ...", "created_time": 1700000000
# }
class Integrations::Facebook::MentionMessageCreator
  def initialize(channel, inbox, change)
    @channel = channel
    @inbox = inbox
    @change = change
  end

  def perform
    return if page_own_mention?
    return unless mention_add?
    return if sender_id.blank?
    return if duplicate?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def page_own_mention?
    sender_id == @channel.page_id
  end

  def mention_add?
    # Mention webhooks have verb: 'add' for new mentions
    @change['verb'].nil? || @change['verb'] == 'add'
  end

  def duplicate?
    return false if external_id.blank?

    Message.exists?(source_id: external_id, inbox_id: @inbox.id)
  end

  def sender_id
    @change['sender_id'] || @change.dig('from', 'id') || post_author_id
  end

  def sender_name
    @change['sender_name'] || @change.dig('from', 'name') || fetched_sender_name || 'Facebook User'
  end

  # When sender_id/name are missing from the webhook payload (common for
  # post mentions from a user's own feed), derive them from the post_id
  # (format: "<author_id>_<post_shortid>") and fetch the name from Graph.
  def post_author_id
    return nil if post_id.blank?

    post_id.split('_').first
  end

  def fetched_sender_name
    return @fetched_sender_name if defined?(@fetched_sender_name)

    uid = post_author_id
    return @fetched_sender_name = nil if uid.blank?

    graph = Koala::Facebook::API.new(@channel.page_access_token)
    @fetched_sender_name = graph.get_object(uid, fields: 'name')&.dig('name')
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch mention sender name for #{post_author_id}: #{e.message}")
    @fetched_sender_name = nil
  end

  def item_type
    @change['item'] # 'post' | 'comment'
  end

  def post_id
    @change['post_id']
  end

  def comment_id
    @change['comment_id']
  end

  def external_id
    comment_id.presence || post_id
  end

  def message_text
    @change['message'].presence || fetch_text
  end

  def fetch_text
    graph = Koala::Facebook::API.new(@channel.page_access_token)
    graph.get_object(external_id, fields: 'message')&.dig('message')
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch mention content for #{external_id}: #{e.message}")
    nil
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
      identifier: post_id
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    post_data = fetch_post_data || {}
    post_content = post_data['message'] || post_data['story'] || @change['message']
    media_url, post_type = extract_post_media(post_data)
    permalink = post_data['permalink_url'] || "https://www.facebook.com/#{post_id}"

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: post_id,
      additional_attributes: {
        type: 'facebook_feed',
        post_id: post_id,
        post_content: post_content,
        post_type: post_type,
        is_mention: true,
        is_ad: false,
        media_url: media_url,
        permalink_url: permalink
      }
    )
  end

  def fetch_post_data
    graph = Koala::Facebook::API.new(@channel.page_access_token)
    graph.get_object(post_id, fields: 'message,story,permalink_url,full_picture,is_published,created_time,attachments{media,media_type,type,url}')
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch mention post data for #{post_id}: #{e.message}")
    nil
  end

  def extract_post_media(post_data)
    attachment = post_data.dig('attachments', 'data', 0)
    media_type = attachment&.dig('media_type') || attachment&.dig('type')
    post_type = case media_type
                when 'video' then 'video'
                when 'photo', 'album' then 'photo'
                else 'status'
                end
    media_url = attachment&.dig('media', 'source').presence ||
                attachment&.dig('media', 'image', 'src').presence ||
                post_data['full_picture'].presence
    [media_url, post_type]
  end

  def create_message
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: message_text,
      source_id: external_id,
      sender: @contact_inbox.contact,
      content_attributes: {
        type: "facebook_mention_#{item_type}",
        post_id: post_id,
        comment_id: comment_id,
        item: item_type
      }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
