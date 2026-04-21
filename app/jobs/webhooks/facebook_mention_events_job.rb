class Webhooks::FacebookMentionEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(page_id, change_json)
    change = JSON.parse(change_json)

    mention_id = change['comment_id'].presence || change['post_id']
    return if mention_id.blank?

    key = format(::Redis::Alfred::FACEBOOK_MENTION_MUTEX, mention_id: mention_id)
    with_lock(key) do
      Channel::FacebookPage.where(page_id: page_id).each do |channel|
        mentions_inbox = channel.mentions_inbox
        next unless mentions_inbox

        ::Integrations::Facebook::MentionMessageCreator.new(channel, mentions_inbox, change).perform
      end
    end
  end
end
