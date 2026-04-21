class BlockedProfile < ApplicationRecord
  belongs_to :account
  belongs_to :contact, optional: true
  belongs_to :blocked_by_user, class_name: 'User', optional: true

  validates :channel_type, presence: true
  validates :platform_user_id, presence: true
  validates :platform_user_id, uniqueness: { scope: [:account_id, :channel_type] }

  scope :active, -> { where('blocked_until IS NULL OR blocked_until > ?', Time.current) }

  def active?
    blocked_until.nil? || blocked_until > Time.current
  end
end
