class Webhooks::FacebookFeedEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(page_id, change_json)
    change = JSON.parse(change_json)

    if comment_event?(change)
      handle_comment(page_id, change)
    elsif visitor_post_event?(page_id, change)
      handle_visitor_post(page_id, change)
    end
  end

  private

  def comment_event?(change)
    change['item'] == 'comment' && change['verb'].in?(%w[add edited])
  end

  def visitor_post_event?(page_id, change)
    return false unless change['verb'].in?(%w[add edited edit])
    return false unless change['item'].in?(%w[post status])

    sender_id = change.dig('from', 'id') || change['sender_id']
    sender_id.present? && sender_id != page_id
  end

  def handle_comment(page_id, change)
    comment_id = change['comment_id']
    return if comment_id.blank?

    key = format(::Redis::Alfred::FACEBOOK_FEED_MUTEX, comment_id: comment_id)
    with_lock(key) do
      Channel::FacebookPage.where(page_id: page_id).each do |channel|
        dispatch_comment_to_inboxes(channel, change)
      end
    end
  end

  def dispatch_comment_to_inboxes(channel, change)
    if (public_inbox = channel.public_inbox)
      ::Integrations::Facebook::FeedMessageCreator.new(channel, public_inbox, change).perform
    end

    # Mirror the comment into the visitor-posts / mentions inbox when the
    # parent post already has a conversation there, so agents see replies
    # on the same thread as the original post.
    [channel.visitor_posts_inbox, channel.mentions_inbox].compact.each do |inbox|
      ::Integrations::Facebook::FeedMessageCreator.new(channel, inbox, change, append_only: true).perform
    end
  end

  def handle_visitor_post(page_id, change)
    post_id = change['post_id']
    return if post_id.blank?

    key = format(::Redis::Alfred::FACEBOOK_FEED_MUTEX, comment_id: post_id)
    with_lock(key) do
      Channel::FacebookPage.where(page_id: page_id).each do |channel|
        visitor_inbox = channel.visitor_posts_inbox
        next unless visitor_inbox

        ::Integrations::Facebook::VisitorPostCreator.new(channel, visitor_inbox, change).perform
      end
    end
  end
end
