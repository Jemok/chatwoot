# Banking demo (#7): every minute, purge expired ConversationLock rows so
# the active set stays small and the UI doesn't render stale "locked by"
# states if the holder's tab crashed without a clean release.
class Internal::ConversationLockSweepJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    expired = ConversationLock.where('expires_at <= ?', Time.current)
    expired.find_each do |lock|
      account_id = lock.account_id
      conv_id = lock.conversation_id
      lock.destroy!
      ConversationLock.broadcast_release(account_id, conv_id)
    end
  end
end
