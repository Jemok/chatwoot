# == Schema Information
#
# Table name: channel_app_store_reviews
#
#  id              :bigint           not null, primary key
#  app_id          :string           not null
#  issuer_id       :string           not null
#  key_id          :string           not null
#  p8_private_key  :text             not null
#  vendor_name     :string
#  last_polled_at  :datetime
#  account_id      :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Channel::AppStoreReviews < ApplicationRecord
  include Channelable
  include Reauthorizable
  self.table_name = 'channel_app_store_reviews'

  encrypts :p8_private_key if Chatwoot.encryption_configured?

  AUTHORIZATION_ERROR_THRESHOLD = 1

  validates :app_id, uniqueness: true, presence: true
  validates :issuer_id, presence: true
  validates :key_id, presence: true
  validates :p8_private_key, presence: true

  def name
    'App Store Reviews'
  end

  def messaging_window_enabled?
    false
  end
end
