class Webhooks::InstagramCommentEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(ig_account_id, change_json)
    change = JSON.parse(change_json)
    comment_id = change['id']
    return if comment_id.blank?

    key = format(::Redis::Alfred::INSTAGRAM_COMMENT_MUTEX, comment_id: comment_id)
    with_lock(key) do
      channel = Channel::Instagram.find_by(instagram_id: ig_account_id)
      return unless channel

      inbox = channel.public_inbox
      return unless inbox

      ::Integrations::Instagram::CommentMessageCreator.new(channel, inbox, change).perform
    end
  end
end
