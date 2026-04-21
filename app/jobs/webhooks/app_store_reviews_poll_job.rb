class Webhooks::AppStoreReviewsPollJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::AppStoreReviews.find_each do |channel|
      ::Integrations::AppStore::ReviewsPoller.new(channel).perform
    rescue StandardError => e
      Rails.logger.warn("[AppStoreReviewsPollJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
