class Webhooks::ThreadsMentionsPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::Threads.find_each do |channel|
      ::Integrations::Threads::MentionsPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[ThreadsMentionsPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
