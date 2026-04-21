class Webhooks::XDmPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::X.find_each do |channel|
      ::Integrations::X::DmPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[XDmPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
