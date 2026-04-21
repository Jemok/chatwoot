class Webhooks::ThreadsMentionEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  # field is 'mentions' or 'quotes' — both route to the Mentions inbox;
  # quote events are flagged via additional_attributes.is_quote = true.
  def perform(threads_user_id, field, change_json)
    change = JSON.parse(change_json)
    mention_id = change['id']
    return if mention_id.blank?

    key = format(::Redis::Alfred::THREADS_MENTION_MUTEX, mention_id: mention_id)
    with_lock(key) do
      channel = Channel::Threads.find_by(threads_user_id: threads_user_id)
      return unless channel

      inbox = channel.mentions_inbox
      return unless inbox

      ::Integrations::Threads::MentionMessageCreator.new(channel, inbox, change, field: field).perform
    end
  end
end
