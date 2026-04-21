# == Schema Information
#
# Table name: channel_linkedin
#
#  id                :bigint           not null, primary key
#  access_token      :string           not null
#  refresh_token     :string
#  expires_at        :datetime         not null
#  username          :string
#  organization_urn  :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#  linkedin_user_urn :string           not null
#
# Indexes
#
#  index_channel_linkedin_on_linkedin_user_urn  (linkedin_user_urn) UNIQUE
#
class Channel::Linkedin < ApplicationRecord
  include Channelable
  include Reauthorizable
  self.table_name = 'channel_linkedin'

  # TODO: Remove guard once encryption keys become mandatory.
  encrypts :access_token if Chatwoot.encryption_configured?
  encrypts :refresh_token if Chatwoot.encryption_configured?

  AUTHORIZATION_ERROR_THRESHOLD = 1

  validates :access_token, presence: true
  validates :linkedin_user_urn, uniqueness: true, presence: true

  after_create_commit :ensure_mentions_inbox
  before_destroy :unsubscribe

  def name
    'LinkedIn'
  end

  # Parent inbox = the member/organization page itself (outbound shares,
  # incoming replies on our own posts when webhooks deliver them).
  def replies_inbox
    inbox
  end

  # Sub-inbox where conversations created from @mentions and tagged posts land.
  # Auto-provisioned on create; gated downstream by scope availability in pollers.
  def mentions_inbox
    account = inbox&.account
    return unless account

    account.inboxes.find_by(channel: self, name: "#{inbox.name} - Mentions")
  end

  def ensure_mentions_inbox
    return if mentions_inbox.present?
    return unless inbox&.account

    sub_inbox = Inbox.create!(channel: self, account: inbox.account, name: "#{inbox.name} - Mentions")
    copy_inbox_members_to(sub_inbox)
  end

  # Mirror parent inbox agent assignments onto the auto-created sub-inbox so
  # the same team sees mentions without manual setup.
  def copy_inbox_members_to(target_inbox)
    user_ids = inbox.inbox_members.pluck(:user_id)
    return if user_ids.blank?

    target_inbox.add_members(user_ids)
  end

  # LinkedIn Event Notifications (webhooks) require Community Management API
  # approval; once granted we'll register subscriptions here. No-op for now.
  def subscribe
    true
  end

  def unsubscribe
    true
  end

  # Delegates to the refresh service so 60-day tokens auto-renew when they
  # approach expiry. No-op when the app doesn't issue refresh tokens.
  def access_token
    Linkedin::RefreshOauthTokenService.new(channel: self).access_token
  end
end
