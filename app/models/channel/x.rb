require 'oauth'

# == Schema Information
#
# Table name: channel_x
#
class Channel::X < ApplicationRecord
  include Channelable
  include Reauthorizable
  self.table_name = 'channel_x'

  encrypts :access_token if Chatwoot.encryption_configured?
  encrypts :access_token_secret if Chatwoot.encryption_configured?

  AUTHORIZATION_ERROR_THRESHOLD = 1

  validates :access_token, presence: true
  validates :access_token_secret, presence: true
  validates :x_user_id, uniqueness: true, presence: true

  after_create_commit :subscribe
  after_create_commit :ensure_mentions_inbox
  after_create_commit :ensure_dm_inbox
  after_update_commit :subscribe, if: :saved_change_to_access_token?
  before_destroy :unsubscribe

  def name
    'X'
  end

  def replies_inbox
    inbox
  end

  def mentions_inbox
    account = inbox&.account
    return unless account

    account.inboxes.find_by(channel: self, name: "#{inbox.name} - Mentions")
  end

  def ensure_mentions_inbox
    return if mentions_inbox.present?
    return unless inbox&.account

    sub = Inbox.create!(channel: self, account: inbox.account, name: "#{inbox.name} - Mentions")
    copy_inbox_members_to(sub)
  end

  def dm_inbox
    account = inbox&.account
    return unless account

    account.inboxes.find_by(channel: self, name: "#{inbox.name} - DMs")
  end

  # OAuth 1.0a apps configured with "Read, Write & Direct Messages" permission
  # always have DM access, so the DM sub-inbox is created unconditionally.
  def ensure_dm_inbox
    return if dm_inbox.present?
    return unless inbox&.account

    sub = Inbox.create!(channel: self, account: inbox.account, name: "#{inbox.name} - DMs")
    copy_inbox_members_to(sub)
  end

  def copy_inbox_members_to(target_inbox)
    user_ids = inbox.inbox_members.pluck(:user_id)
    return if user_ids.blank?

    target_inbox.add_members(user_ids)
  end

  def oauth_consumer
    ::OAuth::Consumer.new(
      GlobalConfigService.load('X_CONSUMER_KEY', nil),
      GlobalConfigService.load('X_CONSUMER_SECRET', nil),
      site: 'https://api.twitter.com'
    )
  end

  def oauth_access_token
    ::OAuth::AccessToken.new(oauth_consumer, access_token, access_token_secret)
  end

  # X v2 Webhooks API (pay-as-you-go) does not require a per-user subscribe
  # call — events flow automatically for users authorized against the app
  # once the webhook URL is registered. Kept as a no-op so legacy callers
  # don't break; will be revisited if a subscription endpoint is reintroduced.
  def subscribe
    Rails.logger.info("[Channel::X#subscribe] no-op for channel=#{id} (v2 webhooks deliver automatically)")
    true
  end

  def unsubscribe
    Rails.logger.info("[Channel::X#unsubscribe] no-op for channel=#{id}")
    true
  end
end
