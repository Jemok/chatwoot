# frozen_string_literal: true

# Processes Facebook `feed` webhook events where a visitor (not the page
# itself) posts directly on the page's timeline.
#
# Each visitor post becomes one conversation in the channel's Visitor Posts
# inbox, keyed by (post_id, contact_id).
class Integrations::Facebook::VisitorPostCreator
  def initialize(channel, inbox, change)
    @channel = channel
    @inbox = inbox
    @change = change
  end

  def perform
    return if sender_id.blank?
    return if duplicate?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def sender_id
    @change.dig('from', 'id') || @change['sender_id']
  end

  def sender_name
    @change.dig('from', 'name') || @change['sender_name'] || 'Facebook User'
  end

  def post_id
    @change['post_id']
  end

  def duplicate?
    Message.exists?(source_id: post_id, inbox_id: @inbox.id)
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
        is_visitor_post: true,
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
    Rails.logger.warn("Failed to fetch visitor post #{post_id}: #{e.message}")
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
    post_data = @post_data_cache ||= (fetch_post_data || {})
    content = @change['message'].presence || post_data['message'].presence || post_data['story'].presence || '(no text — media or link)'

    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: content,
      source_id: post_id,
      sender: @contact_inbox.contact,
      content_attributes: {
        type: 'facebook_visitor_post',
        post_id: post_id,
        item: @change['item']
      }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
