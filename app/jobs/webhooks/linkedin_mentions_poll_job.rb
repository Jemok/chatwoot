class Webhooks::LinkedinMentionsPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::Linkedin.find_each do |channel|
      ::Integrations::Linkedin::MentionsPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[LinkedinMentionsPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
