class Webhooks::LinkedinMessageEventsJob < ApplicationJob
  queue_as :default

  # LinkedIn Messaging API webhooks are partner-only (Sales Navigator /
  # Messaging API partnership). When unavailable we short-circuit so the
  # rest of the integration keeps working.
  def perform(_event_json)
    Rails.logger.info('[LinkedIn webhook] message event received but Messaging API is partner-gated; ignoring')
  end
end
