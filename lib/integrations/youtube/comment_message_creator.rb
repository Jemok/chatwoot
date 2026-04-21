# frozen_string_literal: true

# Threads a YouTube comment into a Chatwoot conversation.
# - Conversation grouping key = videoId (so all comments on one video share a conversation).
# - Skips own-channel comments (don't echo our own replies as incoming).
class Integrations::Youtube::CommentMessageCreator
  def initialize(channel, inbox, comment, video_id, parent_id)
    @channel = channel
    @inbox = inbox
    @comment = comment
    @video_id = video_id
    @parent_id = parent_id
  end

  def perform
    return if comment_id.blank?
    return if author_channel_id.present? && author_channel_id == @channel.youtube_channel_id
    return if duplicate?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      find_or_create_conversation
      create_message
    end
  end

  private

  def comment_id
    @comment['id']
  end

  def snippet
    @snippet ||= @comment['snippet'] || {}
  end

  def author_channel_id
    snippet.dig('authorChannelId', 'value')
  end

  def author_name
    snippet['authorDisplayName'].presence || 'YouTube User'
  end

  def message_text
    snippet['textOriginal'].presence || snippet['textDisplay'].to_s
  end

  def duplicate?
    Message.exists?(source_id: comment_id, inbox_id: @inbox.id)
  end

  def build_contact_inbox
    source_id = author_channel_id.presence || "yt-anon-#{Digest::SHA256.hexdigest(author_name)[0..15]}"
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: source_id,
      inbox: @inbox,
      contact_attributes: { name: author_name }
    ).perform
  end

  def find_or_create_conversation
    @conversation = Conversation.where(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      identifier: @video_id
    ).where.not(status: :resolved).order(created_at: :desc).first

    return if @conversation

    @conversation = Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      identifier: @video_id,
      additional_attributes: { type: 'youtube_comment', video_id: @video_id }
    )
  end

  def create_message
    attrs = { type: 'youtube_comment', video_id: @video_id }
    if @parent_id.present?
      parent = @inbox.messages.find_by(source_id: @parent_id)
      attrs[:in_reply_to] = parent.id if parent
      attrs[:in_reply_to_external_id] = @parent_id
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
