class Webhooks::XReplyEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  # Routes a tweet event to either the replies or mentions inbox:
  # - replies inbox when in_reply_to_user_id_str == channel.x_user_id
  # - mentions inbox otherwise (treat as @mention/quote)
  def perform(x_user_id, tweet_json, users_json)
    tweet = JSON.parse(tweet_json)
    users = JSON.parse(users_json)
    tweet_id = tweet['id_str'] || tweet['id'].to_s
    return if tweet_id.blank?

    key = format(::Redis::Alfred::X_REPLY_MUTEX, reply_id: tweet_id)
    with_lock(key) do
      channel = Channel::X.find_by(x_user_id: x_user_id)
      return unless channel

      if reply_to_us?(tweet, channel)
        inbox = channel.replies_inbox
        ::Integrations::X::ReplyMessageCreator.new(channel, inbox, tweet, users).perform if inbox
      else
        inbox = channel.mentions_inbox
        ::Integrations::X::MentionMessageCreator.new(channel, inbox, tweet, users).perform if inbox
      end
    end
  end

  private

  def reply_to_us?(tweet, channel)
    in_reply_to = tweet['in_reply_to_user_id_str'] || tweet['in_reply_to_user_id'].to_s
    in_reply_to.present? && in_reply_to == channel.x_user_id.to_s
  end
end
