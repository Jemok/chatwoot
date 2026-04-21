class Webhooks::InstagramMentionEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(ig_account_id, change_json)
    change = JSON.parse(change_json)
    mention_id = change['comment_id'].presence || change['media_id']
    return if mention_id.blank?

    key = format(::Redis::Alfred::INSTAGRAM_MENTION_MUTEX, mention_id: mention_id)
    with_lock(key) do
      channel = Channel::Instagram.find_by(instagram_id: ig_account_id)
      return unless channel

      inbox = channel.mentions_inbox
      return unless inbox

      ::Integrations::Instagram::MentionMessageCreator.new(channel, inbox, change).perform
    end
  end
end
