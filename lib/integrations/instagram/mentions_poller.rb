# frozen_string_literal: true

# Polls Graph API for new posts that @-mention our IG business account.
#
# Instagram only delivers real-time `mentions` webhooks for STORY mentions.
# Caption/comment mentions on regular posts must be discovered by polling
# the `/{ig-user-id}/tags` edge (Instagram's mention discovery API).
#
# Each newly seen tagged media is funneled through MentionMessageCreator
# as a synthetic mentions change payload (`{ media_id: ... }`), which
# creates the conversation in the channel's Mentions inbox and dedupes
# via Message#source_id.
#
# Requires the IG token to carry `instagram_business_manage_comments`.
class Integrations::Instagram::MentionsPoller
  TAG_FIELDS = 'id,caption,media_type,permalink,timestamp,username'
  PAGE_LIMIT = 25

  def initialize(channel)
    @channel = channel
  end

  def perform
    inbox = @channel.mentions_inbox
    return unless inbox

    fetch_tagged_media.each do |media|
      media_id = media['id']
      next if media_id.blank?
      next if Message.exists?(source_id: media_id, inbox_id: inbox.id)

      change = {
        'media_id' => media_id,
        'username' => media['username'],
        'caption' => media['caption'],
        'media_type' => media['media_type'],
        'media_url' => media['media_url'],
        'thumbnail_url' => media['thumbnail_url'],
        'permalink' => media['permalink']
      }
      ::Integrations::Instagram::MentionMessageCreator.new(@channel, inbox, change).perform
    end
  end

  private

  def fetch_tagged_media
    response = HTTParty.get(
      "https://graph.instagram.com/v22.0/#{@channel.instagram_id}/tags",
      query: { fields: TAG_FIELDS, limit: PAGE_LIMIT, access_token: @channel.access_token }
    ).parsed_response
    response.is_a?(Hash) ? Array(response['data']) : []
  rescue StandardError => e
    Rails.logger.warn("[Instagram::MentionsPoller] Failed to fetch tags for ig=#{@channel.instagram_id}: #{e.message}")
    []
  end
end
