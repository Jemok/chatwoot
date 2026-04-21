class Webhooks::LinkedinCommentEventsJob < ApplicationJob
  queue_as :default

  # Forwards new comments on our org/member posts to the parent inbox.
  # The comment-message creator (Phase 4) finds the channel by recipient URN
  # and threads under the post URN.
  def perform(event_json)
    event = JSON.parse(event_json)
    recipient_urn = event['recipient'] || event.dig('object', 'recipient')
    channel = find_channel(recipient_urn)
    return unless channel

    inbox = channel.inbox
    return unless inbox

    ::Integrations::Linkedin::CommentMessageCreator.new(channel, inbox, event).perform
  end

  private

  def find_channel(recipient_urn)
    return if recipient_urn.blank?

    Channel::Linkedin.where(linkedin_user_urn: recipient_urn)
                     .or(Channel::Linkedin.where(organization_urn: recipient_urn))
                     .first
  end
end
