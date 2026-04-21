class PolicyViolationLog < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :conversation, optional: true
  belongs_to :inbox, optional: true

  POLICIES = %w[whatsapp_24h facebook_7d denied_action suspicious_login moderation_action user_lifecycle profile_block routing_override].freeze
  validates :policy, presence: true, inclusion: { in: POLICIES }

  scope :recent, ->(limit = 50) { order(id: :desc).limit(limit) }
end
