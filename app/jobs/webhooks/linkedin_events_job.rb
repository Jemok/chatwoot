class Webhooks::LinkedinEventsJob < ApplicationJob
  queue_as :default

  # LinkedIn Event Notifications wrap one or more events under `events`.
  # Single-event payloads (during testing) may also arrive at the top level.
  def perform(payload)
    events = Array(payload['events']).presence || [payload]

    events.each do |event|
      case event['eventType'].to_s
      when 'SOCIAL_ACTIONS_COMMENTS', 'COMMENTS'
        ::Webhooks::LinkedinCommentEventsJob.perform_later(event.to_json)
      when 'ORGANIZATION_SOCIAL_ACTION_NOTIFICATIONS', 'MENTIONS'
        ::Webhooks::LinkedinMentionEventsJob.perform_later(event.to_json)
      when 'MESSAGES', 'MESSAGE_EVENTS'
        ::Webhooks::LinkedinMessageEventsJob.perform_later(event.to_json)
      else
        Rails.logger.info("[LinkedIn webhook] unhandled eventType=#{event['eventType'].inspect}")
      end
    end
  end
end
