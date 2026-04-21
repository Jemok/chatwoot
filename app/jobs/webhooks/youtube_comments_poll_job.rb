class Webhooks::YoutubeCommentsPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::Youtube.find_each do |channel|
      ::Integrations::Youtube::CommentsPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[YoutubeCommentsPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
