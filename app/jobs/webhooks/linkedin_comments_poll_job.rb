class Webhooks::LinkedinCommentsPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::Linkedin.find_each do |channel|
      ::Integrations::Linkedin::CommentsPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[LinkedinCommentsPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
