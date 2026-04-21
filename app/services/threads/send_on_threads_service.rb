# Sends outgoing public replies to Threads.
# Two-step publish flow per Threads API:
#   1. POST /{threads-user-id}/threads → returns `creation_id`
#   2. POST /{threads-user-id}/threads_publish with creation_id → returns published id
# https://developers.facebook.com/docs/threads/posts
#
# Inbound conversations carry `identifier = root_thread_id` (Replies inbox) or
# `identifier = mention_thread_id` (Mentions inbox). Outgoing replies thread
# against the last incoming message's source_id, falling back to the
# conversation identifier (the root thread).
class Threads::SendOnThreadsService < Base::SendOnChannelService
  PUBLISH_POLL_INTERVAL = 0.5
  PUBLISH_POLL_ATTEMPTS = 6

  private

  def channel_class
    Channel::Threads
  end

  def perform_reply
    # Attachments not supported on MVP — text replies only.
    return if message.content.blank?

    creation_id = create_media_container
    return unless creation_id

    published_id = publish_media_container(creation_id)
    message.update!(source_id: published_id) if published_id
  rescue StandardError => e
    handle_error(e)
  end

  def create_media_container
    response = HTTParty.post(
      "https://graph.threads.net/v1.0/#{channel.threads_user_id}/threads",
      query: {
        media_type: 'TEXT',
        text: message.outgoing_content,
        reply_to_id: reply_to_id,
        access_token: channel.access_token
      }.compact
    )

    parsed = response.parsed_response
    if response.success? && parsed['error'].blank?
      parsed['id']
    else
      record_failure(parsed, 'create_media_container')
      nil
    end
  end

  def publish_media_container(creation_id)
    response = HTTParty.post(
      "https://graph.threads.net/v1.0/#{channel.threads_user_id}/threads_publish",
      query: {
        creation_id: creation_id,
        access_token: channel.access_token
      }
    )

    parsed = response.parsed_response
    if response.success? && parsed['error'].blank?
      parsed['id']
    else
      record_failure(parsed, 'publish_media_container')
      nil
    end
  end

  def reply_to_id
    attrs = message.content_attributes || {}
    return attrs['in_reply_to_external_id'] if attrs['in_reply_to_external_id'].present?

    last_incoming = conversation.messages.incoming.where.not(source_id: nil).order(created_at: :desc).first
    last_incoming&.source_id || conversation.identifier
  end

  def record_failure(parsed, context)
    error_message = parsed.is_a?(Hash) ? parsed.dig('error', 'message') : parsed.to_s
    error_code = parsed.is_a?(Hash) ? parsed.dig('error', 'code') : nil

    channel.authorization_error! if error_code == 190

    Rails.logger.error("[Threads::SendOnThreadsService] #{context} failed: #{error_code} - #{error_message}")
    Messages::StatusUpdateService.new(message, 'failed', "#{error_code} - #{error_message}").perform
  end

  def handle_error(error)
    ChatwootExceptionTracker.new(error, account: message.account, user: message.sender).capture_exception
  end
end
