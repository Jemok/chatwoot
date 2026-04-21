class Webhooks::XRepliesPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::X.find_each do |channel|
      ::Integrations::X::RepliesPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[XRepliesPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
