# frozen_string_literal: true

# Polls Graph API for new comments on posts that mention the page.
#
# Facebook does not deliver `feed` webhooks for comments on external posts
# (posts that live on another user's/page's wall where your page is merely
# tagged). This poller bridges that gap by periodically calling
# `/{post_id}/comments` for each open Mentions conversation and funneling
# new comments through FeedMessageCreator into the Mentions inbox.
#
# Requires the page token to have `pages_read_engagement` (or Page Public
# Content Access) — otherwise Graph returns 400 and we log + skip.
class Integrations::Facebook::MentionCommentsPoller
  COMMENT_FIELDS = 'id,message,from,parent,created_time,attachment{type,media,url,title}'

  def initialize(channel)
    @channel = channel
  end

  def perform
    inbox = @channel.mentions_inbox
    return unless inbox

    mention_conversations(inbox).find_each do |conversation|
      poll_conversation(inbox, conversation)
    end
  end

  private

  def mention_conversations(inbox)
    Conversation.where(inbox_id: inbox.id)
                .where("additional_attributes->>'is_mention' = 'true'")
                .where.not(identifier: nil)
                .where.not(status: :resolved)
  end

  def poll_conversation(inbox, conversation)
    post_id = conversation.identifier
    comments = fetch_comments(post_id)
    return if comments.blank?

    comments.each do |comment|
      next if comment['id'].blank?
      next if Message.exists?(source_id: comment['id'], inbox_id: inbox.id)

      change = build_change_payload(post_id, comment)
      ::Integrations::Facebook::FeedMessageCreator.new(@channel, inbox, change).perform
    end
  end

  def fetch_comments(post_id)
    graph = Koala::Facebook::API.new(@channel.page_access_token)
    graph.get_connections(post_id, 'comments', fields: COMMENT_FIELDS, limit: 50)
  rescue StandardError => e
    Rails.logger.warn("[MentionCommentsPoller] Failed to fetch comments for #{post_id}: #{e.message}")
    nil
  end

  def build_change_payload(post_id, comment)
    parent_id = comment.dig('parent', 'id') || post_id
    payload = {
      'item' => 'comment',
      'verb' => 'add',
      'comment_id' => comment['id'],
      'post_id' => post_id,
      'parent_id' => parent_id,
      'from' => comment['from'] || { 'id' => derive_from_id(comment['id']), 'name' => 'Facebook User' },
      'message' => comment['message'],
      'created_time' => comment['created_time']
    }
    attach = comment['attachment']
    payload['photo'] = attach.dig('media', 'image', 'src') if attach.present?
    payload
  end

  # Graph comment ids use `<post_shortid>_<comment_shortid>` — fall back to
  # the post's author id when Facebook strips `from` for privacy.
  def derive_from_id(comment_id)
    return nil if comment_id.blank?

    comment_id.split('_').first
  end
end
