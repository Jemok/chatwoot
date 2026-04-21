# frozen_string_literal: true

# Polls LinkedIn for organization mentions when in org-mode.
#
# LinkedIn does not expose a single "mentions" REST endpoint. Real-time
# mention notifications arrive via the Event Notifications webhook
# (`ORGANIZATION_SOCIAL_ACTION_NOTIFICATIONS`). This poller exists as a
# webhook-recovery fallback that scans the org's notifications feed when
# `r_organization_admin` is granted; otherwise it cleanly no-ops.
class Integrations::Linkedin::MentionsPoller
  def initialize(channel)
    @channel = channel
  end

  def perform
    inbox = @channel.mentions_inbox
    return unless inbox
    return if @channel.organization_urn.blank?

    fetch_notifications.each do |event|
      next if event['id'].blank?
      next if Message.exists?(source_id: event['id'].to_s, inbox_id: inbox.id)

      ::Integrations::Linkedin::MentionMessageCreator.new(@channel, inbox, event).perform
    end
  end

  private

  def fetch_notifications
    response = HTTParty.get(
      'https://api.linkedin.com/rest/organizationNotifications',
      query: { q: 'organization', organization: @channel.organization_urn, notificationTypes: 'List(MENTION_IN_COMMENT,MENTION_IN_SHARE)' },
      headers: {
        'Authorization' => "Bearer #{@channel.access_token}",
        'Accept' => 'application/json',
        'LinkedIn-Version' => GlobalConfigService.load('LINKEDIN_API_VERSION', '202604'),
        'X-Restli-Protocol-Version' => '2.0.0'
      }
    )
    return [] unless response.success?

    Array(JSON.parse(response.body)['elements'])
  rescue StandardError => e
    Rails.logger.warn("[Linkedin::MentionsPoller] channel=#{@channel.id} #{e.class}: #{e.message}")
    []
  end
end
