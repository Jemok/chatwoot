# == Schema Information
#
# Table name: channel_app_store_reviews
#
#  id             :bigint           not null, primary key
#  last_polled_at :datetime
#  p8_private_key :text             not null
#  vendor_name    :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :integer          not null
#  app_id         :string           not null
#  issuer_id      :string           not null
#  key_id         :string           not null
#
# Indexes
#
#  index_channel_app_store_reviews_on_app_id  (app_id) UNIQUE
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
