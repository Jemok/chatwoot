# frozen_string_literal: true

# Processes Facebook feed webhook events (post comments) and creates
# conversations/messages in the public inbox.
#
# Each Facebook post maps to one conversation. Comments on the same post
# are grouped as messages within that conversation.
#
# Sample feed change value:
# {
#   "item": "comment",
#   "verb": "add",
#   "comment_id": "12345_67890",
#   "parent_id": "12345_11111",
#   "post_id": "PAGE_ID_POST_ID",
#   "from": { "id": "USER_ID", "name": "Jane Doe" },
#   "message": "This is a comment",
#   "created_time": 1700000000
# }
class Integrations::Facebook::FeedMessageCreator
  # append_only: when true, only append the comment to an existing conversation
  # (matched by identifier: post_id) in the given inbox. Used to mirror comments
  # on visitor posts / mention posts back into their origin inbox so agents see
  # replies on the same thread as the original post.
  def initialize(channel, inbox, change, append_only: false)
    @channel = channel
    @inbox = inbox
    @change = change
    @append_only = append_only
  end

  def perform
    return if page_own_comment?
    return unless comment_event?
    return if duplicate_message?
    return if @append_only && existing_post_conversation.nil?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      return if @conversation.nil?

      create_message
    end
  end

  private

  def page_own_comment?
    sender_id == @channel.page_id
  end

  def comment_event?
    @change['item'] == 'comment' && @change['verb'] == 'add'
  end

  def duplicate_message?
    return false if comment_id.blank?

    Message.exists?(source_id: comment_id, inbox_id: @inbox.id)
  end

  def existing_post_conversation
    return @existing_post_conversation if defined?(@existing_post_conversation)

    @existing_post_conversation = Conversation.where(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      identifier: post_id
    ).order(created_at: :desc).first
  end

  def sender_id
    @change.dig('from', 'id')
  end

  def sender_name
    @change.dig('from', 'name') || 'Facebook User'
  end

  def comment_id
    @change['comment_id']
  end

  def post_id
    @change['post_id']
  end

  def parent_id
    @change['parent_id']
  end

  def message_text
    @change['message'].presence || fetch_comment_text
  end

  def fetch_comment_text
    comment_data = fetch_comment_data
    @comment_attachment = comment_data&.dig('attachment') if comment_data
    comment_data&.dig('message')
  end

  def fetch_comment_data
    graph = Koala::Facebook::API.new(@channel.page_access_token)
    graph.get_object(comment_id, fields: 'message,attachment{type,media,url,title}')
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch comment data for #{comment_id}: #{e.message}")
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
    if @append_only
      # Mirror mode: attach comments to the existing post conversation
      # (one thread per post, regardless of commenter) in the visitor-posts
      # or mentions inbox. Skip entirely if the post conversation is missing.
      @conversation = existing_post_conversation
      return
    end

    # One conversation per (post, commenter) pair so each customer has
    # their own support thread even when multiple people comment on the
    # same post.
    @conversation = Conversation.where(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      identifier: post_id
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    post_data = fetch_post_data || {}
    post_content = post_data['message'] || post_data['story']
    is_ad = post_data['promotable_id'].present?
    media_url, post_type = extract_post_media(post_data)

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
        is_ad: is_ad,
        media_url: media_url,
        permalink_url: post_data['permalink_url']
      }
    )
  end

  def fetch_post_data
    graph = Koala::Facebook::API.new(@channel.page_access_token)
    graph.get_object(post_id,
                     fields: 'message,story,permalink_url,full_picture,is_published,created_time,promotable_id,attachments{media,media_type,type,url}')
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch post data for #{post_id}: #{e.message}")
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
    msg = @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      content: message_text.presence || '(no text — media or sticker)',
      source_id: comment_id,
      sender: @contact_inbox.contact,
      content_attributes: comment_content_attributes
    )

    attach_comment_media(msg)
    msg
  rescue ActiveRecord::RecordNotUnique
    # Duplicate from parallel webhook delivery — safe to ignore
    nil
  end

  def comment_content_attributes
    attrs = {
      type: 'facebook_feed_comment',
      comment_id: comment_id,
      post_id: post_id,
      parent_id: parent_id
    }

    # Threading: if this comment replies to another comment (not the post),
    # link it to the parent message so the UI renders a reply preview.
    if parent_id.present? && parent_id != post_id
      parent_message = @inbox.messages.find_by(source_id: parent_id) || fetch_and_create_parent_message
      attrs[:in_reply_to] = parent_message.id if parent_message
      attrs[:in_reply_to_external_id] = parent_id
    end

    attrs
  end

  def fetch_and_create_parent_message
    graph = Koala::Facebook::API.new(@channel.page_access_token)
    data = graph.get_object(parent_id, fields: 'message,from,created_time,attachment{type,media,url,title}')
    return nil if data.blank?

    from_id = data.dig('from', 'id')
    from_name = data.dig('from', 'name') || 'Facebook User'
    is_page_author = from_id == @channel.page_id

    contact_inbox = if is_page_author
                      @contact_inbox
                    else
                      ::ContactInboxWithContactBuilder.new(
                        source_id: from_id,
                        inbox: @inbox,
                        contact_attributes: { name: from_name }
                      ).perform
                    end

    msg = @conversation.messages.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: is_page_author ? :outgoing : :incoming,
      content: data['message'],
      source_id: parent_id,
      sender: is_page_author ? nil : contact_inbox.contact,
      content_attributes: {
        type: 'facebook_feed_comment',
        comment_id: parent_id,
        post_id: post_id,
        backfilled: true
      }
    )

    attach_fetched_attachment(msg, data['attachment']) if data['attachment'].present?
    msg
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch parent comment #{parent_id}: #{e.message}")
    nil
  end

  def attach_fetched_attachment(msg, attachment)
    media_url = extract_media_url(attachment)
    return if media_url.blank?

    msg.attachments.create!(
      account_id: @inbox.account_id,
      file_type: comment_attachment_type(attachment['type']),
      external_url: media_url
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to attach fetched parent attachment: #{e.message}")
  end

  def attach_comment_media(msg)
    attachment = @comment_attachment || fetch_comment_attachment
    if attachment
      media_url = extract_media_url(attachment)
      file_type = comment_attachment_type(attachment['type']) if media_url.present?
    end

    # Fallback: Facebook webhook includes 'photo' URL for photo/sticker/GIF comments
    media_url ||= @change['photo']
    file_type ||= 'image' if media_url.present?

    return if media_url.blank?

    msg.attachments.create!(
      account_id: @inbox.account_id,
      file_type: file_type,
      external_url: media_url
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to attach comment media for #{comment_id}: #{e.message}")
  end

  def fetch_comment_attachment
    graph = Koala::Facebook::API.new(@channel.page_access_token)
    result = graph.get_object(comment_id, fields: 'attachment{type,media,url,title}')
    result&.dig('attachment')
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch comment attachment for #{comment_id}: #{e.message}")
    nil
  end

  def extract_media_url(attachment)
    attachment.dig('media', 'image', 'src') || attachment.dig('media', 'source') || attachment['url']
  end

  def comment_attachment_type(type)
    case type
    when 'photo', 'sticker' then 'image'
    when 'animated_image_autoplay', 'animated_image_share' then 'image'
    when 'video_inline', 'video_share_youtube' then 'video'
    when 'share' then 'share'
    else 'image'
    end
  end
end
