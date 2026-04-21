class Webhooks::InstagramMentionsPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::Instagram.find_each do |channel|
      ::Integrations::Instagram::MentionsPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[InstagramMentionsPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
