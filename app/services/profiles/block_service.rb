# Banking demo: platform-side profile block for public-comment channels.
# Attempts a native API call (Facebook `/{page_id}/blocked`, X block endpoint)
# and falls back to simulated mode when `MODERATION_SIMULATED=true` or the
# access token lacks the required scopes. Local `BlockedProfile` record is
# always persisted by the controller — this service only handles the
# platform round-trip.
class Profiles::BlockService
  pattr_initialize [:blocked_profile!, :inbox]

  def perform!
    return { simulated: true, reason: 'simulated_env' } if simulated_env?

    case blocked_profile.channel_type
    when 'Channel::FacebookPage' then facebook_block
    when 'Channel::X', 'Channel::TwitterProfile' then twitter_block
    else { simulated: true, reason: 'channel_unsupported' }
    end
  end

  private

  def simulated_env?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('MODERATION_SIMULATED', 'true'))
  end

  def page_channel
    @page_channel ||= inbox&.channel if inbox&.channel_type == 'Channel::FacebookPage'
    @page_channel ||= blocked_profile.account.facebook_pages.find_by(page_id: blocked_profile.platform_user_id) ||
                      blocked_profile.account.facebook_pages.first
  end

  def facebook_block
    return { simulated: true, reason: 'no_page_channel' } if page_channel.blank?

    response = HTTParty.post(
      "https://graph.facebook.com/v19.0/#{page_channel.page_id}/blocked",
      query: { access_token: page_channel.page_access_token, user: blocked_profile.platform_user_id }
    )
    if response.success? && response.parsed_response.is_a?(Hash) && response.parsed_response['success']
      { simulated: false, provider: 'facebook' }
    else
      { simulated: true, reason: "facebook_error:#{response.parsed_response.dig('error', 'message')}" }
    end
  rescue StandardError => e
    { simulated: true, reason: "facebook_exception:#{e.message}" }
  end

  # X/Twitter native block requires user-context OAuth and is simulated in
  # the demo — we keep the audit trail honest and let admins document the
  # action out-of-band.
  def twitter_block
    { simulated: true, reason: 'twitter_requires_user_oauth' }
  end
end
