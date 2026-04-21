class Webhooks::ThreadsReplyEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(threads_user_id, change_json)
    change = JSON.parse(change_json)
    reply_id = change['id']
    return if reply_id.blank?

    key = format(::Redis::Alfred::THREADS_REPLY_MUTEX, reply_id: reply_id)
    with_lock(key) do
      channel = Channel::Threads.find_by(threads_user_id: threads_user_id)
      return unless channel

      inbox = channel.replies_inbox
      return unless inbox

      ::Integrations::Threads::ReplyMessageCreator.new(channel, inbox, change).perform
    end
  end
end
