# == Schema Information
#
# Table name: channel_play_store_reviews
#
#  id                    :bigint           not null, primary key
#  credentials_json      :text             not null
#  last_polled_at        :datetime
#  package_name          :string           not null
#  service_account_email :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#
# Indexes
#
#  index_channel_play_store_reviews_on_package_name  (package_name) UNIQUE
#
class Channel::PlayStoreReviews < ApplicationRecord
  include Channelable
  include Reauthorizable
  self.table_name = 'channel_play_store_reviews'
  encrypts :credentials_json if Chatwoot.encryption_configured?
  AUTHORIZATION_ERROR_THRESHOLD = 1
  validates :package_name, uniqueness: true, presence: true
  validates :credentials_json, presence: true
  def name
    'Play Store Reviews'
  end

  def messaging_window_enabled?
    true
  end
end
