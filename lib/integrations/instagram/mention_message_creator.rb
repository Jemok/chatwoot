# frozen_string_literal: true

# Processes Instagram `mentions` webhook events — fired when someone
# @-mentions our IG business account in their own caption or comment.
class Integrations::Instagram::MentionMessageCreator
  def initialize(channel, inbox, change)
    @channel = channel
    @inbox = inbox
    @change = change
  end

  def perform
    return if media_id.blank?
    return if duplicate_message?

    resolve_mention_details
    # Instagram does not expose owner.id for media owned by other accounts
    # (privacy boundary on /mentioned_media). Fall back to username as the
    # stable per-contact source_id so caption mentions still create contacts.
    @sender_id ||= @sender_name.presence
    return if @sender_id.blank?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def media_id
    @change['media_id']
  end

  def comment_id
    @change['comment_id']
  end

  def external_id
    comment_id.presence || media_id
  end

  def duplicate_message?
    Message.exists?(source_id: external_id, inbox_id: @inbox.id)
  end

  def resolve_mention_details
    if comment_id.present?
      data = fetch_mentioned_comment || {}
      @sender_id = data.dig('user', 'id') || data.dig('from', 'id')
      @sender_name = data.dig('user', 'username') || data.dig('from', 'username') || @change['username'] || 'Instagram User'
      @message_text = data['text'] || @change['text']
      media = data['media'] || fetch_mentioned_media || @change.slice('media_url', 'thumbnail_url', 'permalink', 'media_type')
      @media_url = media['media_url'] || media['thumbnail_url']
      @permalink = media['permalink']
      @post_type = post_type_for(media['media_type'])
    else
      data = fetch_mentioned_media || {}
      @sender_id = data.dig('owner', 'id')
      @sender_name = data['username'] || @change['username'] || 'Instagram User'
      @message_text = data['caption'] || @change['caption']
      @media_url = data['media_url'] || data['thumbnail_url'] || @change['media_url'] || @change['thumbnail_url']
      @permalink = data['permalink'] || @change['permalink']
      @post_type = post_type_for(data['media_type'] || @change['media_type'])
    end
  end

  def fetch_mentioned_media
    fields = "mentioned_media.media_id(#{media_id}){caption,media_type,media_url,thumbnail_url,permalink,owner,username,timestamp}"
    graph_get(@channel.instagram_id, fields: fields)&.dig('mentioned_media')
  end

  def fetch_mentioned_comment
    fields = "mentioned_comment.comment_id(#{comment_id}){text,timestamp,user,media{media_type,media_url,thumbnail_url,permalink}}"
    graph_get(@channel.instagram_id, fields: fields)&.dig('mentioned_comment')
  end

  def graph_get(path, query)
    HTTParty.get(
      "https://graph.instagram.com/v22.0/#{path}",
      query: query.merge(access_token: @channel.access_token)
    ).parsed_response
  rescue StandardError => e
    Rails.logger.warn("[Instagram::MentionMessageCreator] Graph fetch failed for #{path}: #{e.message}")
    nil
  end

  def post_type_for(media_type)
    case media_type
    when 'VIDEO' then 'video'
    when 'IMAGE', 'CAROUSEL_ALBUM' then 'photo'
    else 'status'
    end
  end

  def build_contact_inbox
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: @sender_id,
      inbox: @inbox,
      contact_attributes: { name: @sender_name }
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

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: media_id,
      additional_attributes: {
        type: 'instagram_feed',
        post_id: media_id,
        post_content: @message_text,
        post_type: @post_type,
        is_mention: true,
        media_url: @media_url,
        permalink_url: @permalink
      }
    )
  end

  def create_message
    @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: @message_text,
      source_id: external_id,
      sender: @contact_inbox.contact,
      content_attributes: {
        type: comment_id.present? ? 'instagram_mention_comment' : 'instagram_mention_post',
        post_id: media_id,
        comment_id: comment_id,
        item: comment_id.present? ? 'comment' : 'post'
      }
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
