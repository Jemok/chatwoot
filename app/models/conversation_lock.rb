# Single-active-responder lock per conversation.
# - Acquired when an agent opens a conversation editor
# - Refreshed on activity (heartbeat)
# - Released on send / leave / TTL expiry
# - Supervisor takeover overrides regardless of holder
# == Schema Information
#
# Table name: conversation_locks
#
#  id                  :bigint           not null, primary key
#  expires_at          :datetime         not null
#  supervisor_takeover :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  conversation_id     :bigint           not null
#  user_id             :bigint           not null
#
# Indexes
#
#  index_conversation_locks_on_conversation_id  (conversation_id) UNIQUE
#  index_conversation_locks_on_expires_at       (expires_at)
#  index_conversation_locks_on_user_id          (user_id)
#
class ConversationLock < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
  belongs_to :account

  DEFAULT_TTL = 2.minutes

  scope :active, -> { where('expires_at > ?', Time.current) }

  def self.acquire!(conversation:, user:, ttl_seconds: DEFAULT_TTL, supervisor_takeover: false)
    lock = find_or_initialize_by(conversation_id: conversation.id)
    expires_at = Time.current + ttl_seconds
    previous_holder_id = lock.persisted? ? lock.user_id : nil

    raise ConversationLock::Conflict.new(lock) if lock.persisted? && lock.user_id != user.id && lock.expires_at > Time.current && !supervisor_takeover

    lock.assign_attributes(
      account_id: conversation.account_id,
      user_id: user.id,
      expires_at: expires_at,
      supervisor_takeover: supervisor_takeover
    )
    lock.save!
    lock.audit_takeover!(previous_holder_id: previous_holder_id) if supervisor_takeover && previous_holder_id && previous_holder_id != user.id
    lock.broadcast_state(:locked)
    lock
  end

  def self.release!(conversation:, user:)
    lock = find_by(conversation_id: conversation.id)
    return unless lock
    return unless lock.user_id == user.id

    conv_id = lock.conversation_id
    account_id = lock.account_id
    lock.destroy!
    broadcast_release(account_id, conv_id)
  end

  def self.broadcast_release(account_id, conversation_id)
    pubsub_tokens = Account.find(account_id).users.pluck(:pubsub_token).compact
    display_id = Conversation.where(id: conversation_id).pick(:display_id)
    ActionCableBroadcastJob.perform_later(
      pubsub_tokens,
      'conversation.lock.released',
      { conversation_id: conversation_id, display_id: display_id }
    )
  rescue StandardError => e
    Rails.logger.warn("ConversationLock release broadcast failed: #{e.message}")
  end

  def broadcast_state(state)
    payload = {
      conversation_id: conversation_id,
      display_id: conversation&.display_id,
      user_id: user_id,
      user_name: user.name,
      expires_at: expires_at.to_i,
      supervisor_takeover: supervisor_takeover,
      state: state
    }
    pubsub_tokens = account.users.pluck(:pubsub_token).compact
    ActionCableBroadcastJob.perform_later(pubsub_tokens, "conversation.lock.#{state}", payload)
  rescue StandardError => e
    Rails.logger.warn("ConversationLock broadcast failed: #{e.message}")
  end

  # Banking demo (#7): admins can override an active lock. We record the
  # override in the audit trail so reviewers can see who steamrolled whom.
  def audit_takeover!(previous_holder_id:)
    previous = User.find_by(id: previous_holder_id)
    PolicyViolationLog.create!(
      account_id: account_id,
      user_id: user_id,
      conversation_id: conversation_id,
      inbox_id: conversation&.inbox_id,
      policy: 'denied_action',
      action_attempted: 'lock_takeover',
      details: "Supervisor #{user.name} took over lock previously held by #{previous&.name || "user ##{previous_holder_id}"}"
    )
  rescue StandardError => e
    Rails.logger.warn("ConversationLock audit_takeover failed: #{e.message}")
  end

  class Conflict < StandardError
    attr_reader :lock

    def initialize(lock)
      @lock = lock
      super("Conversation locked by #{lock.user&.name || 'another agent'} until #{lock.expires_at}")
    end
  end
end
