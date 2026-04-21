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
