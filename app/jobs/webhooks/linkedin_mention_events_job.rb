class Webhooks::LinkedinMentionEventsJob < ApplicationJob
  queue_as :default

  # Routes organization/member mention notifications to the Mentions sub-inbox.
  def perform(event_json)
    event = JSON.parse(event_json)
    recipient_urn = event['recipient'] || event.dig('object', 'recipient')
    channel = find_channel(recipient_urn)
    return unless channel

    inbox = channel.mentions_inbox
    return unless inbox

    ::Integrations::Linkedin::MentionMessageCreator.new(channel, inbox, event).perform
  end

  private

  def find_channel(recipient_urn)
    return if recipient_urn.blank?

    Channel::Linkedin.where(linkedin_user_urn: recipient_urn)
                     .or(Channel::Linkedin.where(organization_urn: recipient_urn))
                     .first
  end
end
