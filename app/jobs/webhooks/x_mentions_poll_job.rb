class Webhooks::XMentionsPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::X.find_each do |channel|
      ::Integrations::X::MentionsPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[XMentionsPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
