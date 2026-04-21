# == Schema Information
#
# Table name: channel_youtube
#
#  id                 :bigint           not null, primary key
#  access_token       :string           not null
#  refresh_token      :string
#  expires_at         :datetime         not null
#  channel_title      :string
#  last_polled_at     :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :integer          not null
#  youtube_channel_id :string           not null
#
class Channel::Youtube < ApplicationRecord
  include Channelable
  include Reauthorizable
  self.table_name = 'channel_youtube'

  encrypts :access_token if Chatwoot.encryption_configured?
  encrypts :refresh_token if Chatwoot.encryption_configured?

  AUTHORIZATION_ERROR_THRESHOLD = 1

  validates :access_token, presence: true
  validates :youtube_channel_id, uniqueness: true, presence: true

  def name
    'YouTube'
  end

  def messaging_window_enabled?
    false
  end

  # Auto-refresh on access. Google access tokens expire in ~1h.
  def access_token
    Youtube::RefreshOauthTokenService.new(channel: self).access_token
  end
end
