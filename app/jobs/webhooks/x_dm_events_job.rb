class Webhooks::XDmEventsJob < MutexApplicationJob
  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  def perform(x_user_id, dm_json, users_json)
    dm = JSON.parse(dm_json)
    users = JSON.parse(users_json)
    dm_id = dm['id'].to_s
    return if dm_id.blank?

    key = format(::Redis::Alfred::X_DM_MUTEX, dm_id: dm_id)
    with_lock(key) do
      channel = Channel::X.find_by(x_user_id: x_user_id)
      return unless channel
      return unless channel.dm_scope_granted?

      inbox = channel.dm_inbox
      return unless inbox

      ::Integrations::X::DmMessageCreator.new(channel, inbox, dm, users).perform
    end
  end
end
