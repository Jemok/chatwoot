# frozen_string_literal: true

# Polls X API v2 `/2/tweets/search/recent?query=to:<username>` for tweets
# that reply to the connected user. Complements MentionsPoller, which only
# returns tweets that explicitly @-mention the user.
#
# Replies land in the same Mentions inbox as MentionsPoller and are routed
# through ReplyMessageCreator so they thread correctly under their root
# conversation_id.
class Integrations::X::RepliesPoller
  TWEET_FIELDS = 'author_id,created_at,conversation_id,in_reply_to_user_id,referenced_tweets'
  USER_FIELDS = 'name,username'
  PAGE_LIMIT = 25
  # cap how many recent mention/reply threads we re-scan per run to bound API usage
  THREAD_SCAN_LIMIT = 10
  # X Basic recent-search query is capped at 512 chars; each
  # `conversation_id:<19-digit-id>` + ' OR ' separator is ~42 chars.
  THREAD_BATCH_SIZE = 10
  THREAD_LOOKBACK = 24.hours

  def initialize(channel)
    @channel = channel
  end

  def perform
    @inbox = @channel.mentions_inbox
    return unless @inbox
    return if @channel.username.blank?

    poll_to_username
    poll_open_threads
  end

  private

  # Catches replies addressed directly to us (`@username ...`).
  def poll_to_username
    body = fetch_replies
    process_tweets(Array(body['data']), (body.dig('includes', 'users') || []).index_by { |u| u['id'].to_s })
  end

  # Catches replies posted *inside* an existing mention/reply thread that don't
  # explicitly @-mention us (e.g. person A mentions us, person B replies to A).
  # Batches all open thread ids into a single `conversation_id:(a OR b OR …)`
  # query to keep us well under the recent-search rate limit.
  def poll_open_threads
    ids = recent_thread_ids
    return if ids.empty?

    ids.each_slice(THREAD_BATCH_SIZE) do |chunk|
      query = "(#{chunk.map { |id| "conversation_id:#{id}" }.join(' OR ')})"
      body = search_recent(query)
      process_tweets(Array(body['data']), (body.dig('includes', 'users') || []).index_by { |u| u['id'].to_s })
    end
  end

  def recent_thread_ids
    @inbox.conversations
          .where(status: %i[open pending snoozed])
          .where('conversations.updated_at > ?', THREAD_LOOKBACK.ago)
          .order(updated_at: :desc)
          .limit(THREAD_SCAN_LIMIT)
          .pluck(:identifier)
          .compact
          .uniq
  end

  def process_tweets(tweets, users)
    tweets.each do |tweet|
      next if tweet['author_id'].to_s == @channel.x_user_id.to_s
      next if Message.exists?(source_id: tweet['id'].to_s, inbox_id: @inbox.id)

      ::Integrations::X::ReplyMessageCreator.new(@channel, @inbox, normalize(tweet), users).perform
    end
  end

  def normalize(tweet)
    tweet.merge(
      'id_str' => tweet['id'].to_s,
      'user_id_str' => tweet['author_id'].to_s,
      'in_reply_to_user_id_str' => tweet['in_reply_to_user_id'].to_s,
      'conversation_id_str' => tweet['conversation_id'].to_s,
      'in_reply_to_status_id_str' => parent_tweet_id(tweet)
    )
  end

  def parent_tweet_id(tweet)
    referenced = Array(tweet['referenced_tweets']).find { |r| r['type'] == 'replied_to' }
    referenced&.dig('id').to_s
  end

  def fetch_replies
    query = "to:#{@channel.username} -is:retweet"
    search_recent(query)
  end

  def search_recent(query)
    url = 'https://api.twitter.com/2/tweets/search/recent' \
          "?query=#{CGI.escape(query)}&tweet.fields=#{TWEET_FIELDS}&user.fields=#{USER_FIELDS}&expansions=author_id&max_results=#{PAGE_LIMIT}"
    response = @channel.oauth_access_token.get(url, 'Accept' => 'application/json')
    parsed = JSON.parse(response.body)
    parsed.is_a?(Hash) ? parsed : {}
  rescue StandardError => e
    Rails.logger.warn("[X::RepliesPoller] channel=#{@channel.id} query=#{query.inspect} error=#{e.class}: #{e.message}")
    {}
  end
end
