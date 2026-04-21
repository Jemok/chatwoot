# Sends outgoing replies/posts to LinkedIn.
#
# Routing per conversation type (set by inbound creators in Phase 3/4):
# - 'linkedin_comment' (parent inbox, also default) → POST a comment under
#   the original post URN (or a nested reply under another comment).
# - 'linkedin_mention' (Mentions sub-inbox) → same as comment; reply lives
#   as a comment on the mentioned post.
#
# Uses LinkedIn Versioned REST `/rest/socialActions/{post_urn}/comments`.
# Direct Messages are partner-gated and surface as a recorded failure
# until the Messaging API partnership lands.
class Linkedin::SendOnLinkedinService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Linkedin
  end

  def perform_reply
    return if message.content.blank?
    return if target_post_urn.blank?

    response = post_comment
    parsed = parse(response)

    if response.success? && parsed['id'].present?
      message.update!(source_id: parsed['id'])
    else
      record_failure(parsed, response.code)
    end
  rescue StandardError => e
    handle_error(e)
  end

  def post_comment
    HTTParty.post(
      "https://api.linkedin.com/rest/socialActions/#{CGI.escape(target_post_urn)}/comments",
      body: comment_body.to_json,
      headers: api_headers
    )
  end

  def comment_body
    body = {
      actor: actor_urn,
      object: target_post_urn,
      message: { text: message.outgoing_content }
    }
    body[:parentComment] = parent_comment_urn if parent_comment_urn.present?
    body
  end

  def actor_urn
    channel.organization_urn.presence || channel.linkedin_user_urn
  end

  # Conversation `identifier` is the post URN (CommentMessageCreator/
  # MentionMessageCreator both key off post_urn).
  def target_post_urn
    conversation.additional_attributes['post_id'].presence || conversation.identifier
  end

  # When replying to a specific incoming comment, thread under it.
  def parent_comment_urn
    attrs = message.content_attributes || {}
    return attrs['in_reply_to_external_id'] if attrs['in_reply_to_external_id'].present?

    return unless attrs['in_reply_to'].present?

    ::Message.find_by(id: attrs['in_reply_to'])&.source_id
  end

  def api_headers
    {
      'Authorization' => "Bearer #{channel.access_token}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'LinkedIn-Version' => GlobalConfigService.load('LINKEDIN_API_VERSION', '202604'),
      'X-Restli-Protocol-Version' => '2.0.0'
    }
  end

  def parse(response)
    JSON.parse(response.body)
  rescue StandardError
    {}
  end

  # 401 from LinkedIn = invalid/expired token → mark for re-auth.
  def record_failure(parsed, status_code)
    channel.authorization_error! if status_code.to_i == 401

    error_code = parsed['serviceErrorCode'] || parsed['status'] || status_code
    error_message = parsed['message'] || parsed['error'] || 'unknown error'

    Rails.logger.error("[Linkedin::SendOnLinkedinService] post failed: #{error_code} - #{error_message}")
    Messages::StatusUpdateService.new(message, 'failed', "#{error_code} - #{error_message}").perform
  end

  def handle_error(error)
    ChatwootExceptionTracker.new(error, account: message.account, user: message.sender).capture_exception
    Messages::StatusUpdateService.new(message, 'failed', error.message).perform
  end
end
