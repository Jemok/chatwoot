class Facebook::SendOnFacebookFeedService < Base::SendOnChannelService
  private

  def channel_class
    Channel::FacebookPage
  end

  def perform_reply
    return unless message.content.present?

    reply_to_comment
  rescue Koala::Facebook::ClientError => e
    Rails.logger.error "Facebook::SendOnFacebookFeedService: Error replying to comment: #{e.message}"
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
  end

  def reply_to_comment
    parent_comment_id = find_parent_comment_id
    return unless parent_comment_id

    graph = Koala::Facebook::API.new(channel.page_access_token)
    result = graph.put_comment(parent_comment_id, message.content)

    message.update!(source_id: result['id']) if result['id'].present?
  end

  def find_parent_comment_id
    # If the agent explicitly replied to a specific message, target that comment.
    in_reply_to_id = message.content_attributes['in_reply_to']
    if in_reply_to_id.present?
      referenced = conversation.messages.find_by(id: in_reply_to_id)
      return referenced.source_id if referenced&.source_id.present?
    end

    # Otherwise, reply to the latest incoming comment, falling back to the post.
    last_incoming = conversation.messages.incoming.where.not(source_id: nil).order(created_at: :desc).first
    last_incoming&.source_id || conversation.identifier
  end
end
