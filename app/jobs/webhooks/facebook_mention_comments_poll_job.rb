class Webhooks::FacebookMentionCommentsPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::FacebookPage.find_each do |channel|
      ::Integrations::Facebook::MentionCommentsPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[FacebookMentionCommentsPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
