# frozen_string_literal: true

# Polls Graph API for threads that @-mention our Threads account.
#
# Real-time `mentions` webhook delivery from Threads has indexing lag
# and can miss caption mentions (same pattern as Instagram). This poller
# is a 5-minute fallback that funnels new mentions through
# MentionMessageCreator, which dedupes via Message#source_id.
class Integrations::Threads::MentionsPoller
  MENTION_FIELDS = 'id,media_type,media_url,thumbnail_url,text,permalink,timestamp,username'
  PAGE_LIMIT = 25

  def initialize(channel)
    @channel = channel
  end

  def perform
    inbox = @channel.mentions_inbox
    return unless inbox

    fetch_mentions.each do |mention|
      mention_id = mention['id']
      next if mention_id.blank?
      next if Message.exists?(source_id: mention_id, inbox_id: inbox.id)

      ::Integrations::Threads::MentionMessageCreator.new(@channel, inbox, mention, field: 'mentions').perform
    end
  end

  private

  def fetch_mentions
    response = HTTParty.get(
      "https://graph.threads.net/v1.0/#{@channel.threads_user_id}/mentions",
      query: { fields: MENTION_FIELDS, limit: PAGE_LIMIT, access_token: @channel.access_token }
    ).parsed_response
    response.is_a?(Hash) ? Array(response['data']) : []
  rescue StandardError => e
    Rails.logger.warn("[Threads::MentionsPoller] Failed to fetch mentions for threads_user=#{@channel.threads_user_id}: #{e.message}")
    []
  end
end
