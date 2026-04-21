# frozen_string_literal: true

# Polls X API v2 `/2/dm_events` for incoming Direct Messages and feeds them
# into Integrations::X::DmMessageCreator. This is the OAuth 1.0a polling
# fallback for accounts without Account Activity API (webhook) access.
class Integrations::X::DmPoller
  EVENT_FIELDS = 'id,event_type,text,sender_id,dm_conversation_id,created_at'
  EXPANSIONS = 'sender_id'
  USER_FIELDS = 'name,username'
  PAGE_LIMIT = 20

  def initialize(channel)
    @channel = channel
  end

  def perform
    inbox = @channel.dm_inbox
    return unless inbox

    body = fetch_dm_events
    events = Array(body['data'])
    users = (body.dig('includes', 'users') || []).index_by { |u| u['id'].to_s }

    events.each do |event|
      next unless event['event_type'] == 'MessageCreate'

      ::Integrations::X::DmMessageCreator.new(@channel, inbox, normalize(event), users).perform
    end
  end

  private

  # Adapt v2 `/2/dm_events` shape into the Account-Activity-style hash the
  # existing DmMessageCreator already understands.
  def normalize(event)
    {
      'id' => event['id'].to_s,
      'created_timestamp' => event['created_at'],
      'message_create' => {
        'sender_id' => event['sender_id'].to_s,
        'message_data' => { 'text' => event['text'] }
      },
      'dm_conversation_id' => event['dm_conversation_id'].to_s
    }
  end

  def fetch_dm_events
    url = 'https://api.twitter.com/2/dm_events' \
          "?dm_event.fields=#{EVENT_FIELDS}&expansions=#{EXPANSIONS}&user.fields=#{USER_FIELDS}&max_results=#{PAGE_LIMIT}"
    response = @channel.oauth_access_token.get(url, 'Accept' => 'application/json')
    parsed = JSON.parse(response.body)
    parsed.is_a?(Hash) ? parsed : {}
  rescue StandardError => e
    Rails.logger.warn("[X::DmPoller] channel=#{@channel.id} error=#{e.class}: #{e.message}")
    {}
  end
end
