# == Schema Information
#
# Table name: blocked_profiles
#
#  id                 :bigint           not null, primary key
#  blocked_until      :datetime
#  channel_type       :string           not null
#  reason             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  blocked_by_user_id :bigint
#  contact_id         :bigint
#  platform_user_id   :string           not null
#
# Indexes
#
#  idx_blocked_profiles_on_account_channel_platform_uid  (account_id,channel_type,platform_user_id) UNIQUE
#  index_blocked_profiles_on_account_id                  (account_id)
#  index_blocked_profiles_on_contact_id                  (contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
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
