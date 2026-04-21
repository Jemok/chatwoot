class Webhooks::ThreadsTokenRefreshJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::Threads.find_each do |channel|
      ::Threads::RefreshOauthTokenService.new(channel: channel).access_token
    rescue StandardError => e
      Rails.logger.warn("[ThreadsTokenRefreshJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
