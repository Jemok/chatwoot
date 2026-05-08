# == Schema Information
#
# Table name: policy_violation_logs
#
#  id               :bigint           not null, primary key
#  action_attempted :string
#  details          :text
#  policy           :string           not null
#  request_ip       :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  conversation_id  :bigint
#  inbox_id         :bigint
#  user_id          :bigint
#
# Indexes
#
#  index_policy_violation_logs_on_account_created_at  (account_id,created_at)
#  index_policy_violation_logs_on_account_id          (account_id)
#  index_policy_violation_logs_on_conversation_id     (conversation_id)
#  index_policy_violation_logs_on_policy              (policy)
#
class PolicyViolationLog < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :conversation, optional: true
  belongs_to :inbox, optional: true

  POLICIES = %w[whatsapp_24h facebook_7d denied_action suspicious_login moderation_action user_lifecycle profile_block routing_override].freeze
  validates :policy, presence: true, inclusion: { in: POLICIES }

  scope :recent, ->(limit = 50) { order(id: :desc).limit(limit) }
end
