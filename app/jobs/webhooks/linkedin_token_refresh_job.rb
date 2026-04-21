class Webhooks::LinkedinTokenRefreshJob < ApplicationJob
  queue_as :scheduled_jobs

  # Daily sweep that touches `access_token` on each LinkedIn channel —
  # the getter delegates to RefreshOauthTokenService which only refreshes
  # tokens within 10 days of expiry.
  def perform
    Channel::Linkedin.where('expires_at < ?', 11.days.from_now).find_each do |channel|
      channel.access_token
    rescue StandardError => e
      Rails.logger.warn("[LinkedinTokenRefreshJob] channel=#{channel.id} error=#{e.message}")
    end
  end
end
