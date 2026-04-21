class Webhooks::PlayStoreReviewsPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::PlayStoreReviews.find_each do |channel|
      ::Integrations::PlayStore::ReviewsPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[PlayStoreReviewsPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
