# frozen_string_literal: true

# Polls X API v2 `/2/users/:id/mentions` for tweets mentioning our user.
# Webhook delivery via Account Activity API can lag or be unavailable for
# accounts without elevated access; this is the 5-minute fallback.
class Integrations::X::MentionsPoller
  TWEET_FIELDS = 'author_id,created_at,conversation_id,in_reply_to_user_id,referenced_tweets'
  USER_FIELDS = 'name,username'
  PAGE_LIMIT = 25

  def initialize(channel)
    @channel = channel
  end

  def perform
    inbox = @channel.mentions_inbox
    return unless inbox

    body = fetch_mentions
    tweets = Array(body['data'])
    users = (body.dig('includes', 'users') || []).index_by { |u| u['id'].to_s }

    tweets.each do |tweet|
      tweet_id = tweet['id'].to_s
      next if tweet_id.blank?
      next if Message.exists?(source_id: tweet_id, inbox_id: inbox.id)

      normalized = normalize(tweet)
      ::Integrations::X::MentionMessageCreator.new(@channel, inbox, normalized, users).perform
    end
  end

  private

  def normalize(tweet)
    tweet.merge(
      'id_str' => tweet['id'].to_s,
      'user_id_str' => tweet['author_id'].to_s,
      'in_reply_to_user_id_str' => tweet['in_reply_to_user_id'].to_s,
      'conversation_id_str' => tweet['conversation_id'].to_s
    )
  end

  def fetch_mentions
    url = "https://api.twitter.com/2/users/#{@channel.x_user_id}/mentions" \
          "?tweet.fields=#{TWEET_FIELDS}&user.fields=#{USER_FIELDS}&expansions=author_id&max_results=#{PAGE_LIMIT}"
    response = @channel.oauth_access_token.get(url, 'Accept' => 'application/json')
    parsed = JSON.parse(response.body)
    parsed.is_a?(Hash) ? parsed : {}
  rescue StandardError => e
    Rails.logger.warn("[X::MentionsPoller] Failed to fetch mentions for x_user=#{@channel.x_user_id}: #{e.message}")
    {}
  end
end
