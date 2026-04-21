# == Schema Information
#
# Table name: channel_threads
#
#  id              :bigint           not null, primary key
#  access_token    :string           not null
#  expires_at      :datetime         not null
#  username        :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :integer          not null
#  threads_user_id :string           not null
#
# Indexes
#
#  index_channel_threads_on_threads_user_id  (threads_user_id) UNIQUE
#
class Channel::Threads < ApplicationRecord
  include Channelable
  include Reauthorizable
  self.table_name = 'channel_threads'

  # TODO: Remove guard once encryption keys become mandatory.
  encrypts :access_token if Chatwoot.encryption_configured?

  AUTHORIZATION_ERROR_THRESHOLD = 1

  validates :access_token, presence: true
  validates :threads_user_id, uniqueness: true, presence: true

  after_create_commit :subscribe
  after_create_commit :ensure_mentions_inbox
  # Re-register webhook subscriptions whenever the token changes
  # (e.g. OAuth reauthorization) so newly-granted fields get picked
  # up without a manual resubscribe.
  after_update_commit :subscribe, if: :saved_change_to_access_token?
  before_destroy :unsubscribe

  def name
    'Threads'
  end

  # The parent inbox is the Replies surface (replies on our own threads).
  # Threads has no DM API, so there is no separate "Public" sub-inbox.
  def replies_inbox
    inbox
  end

  # Returns the mentions inbox where conversations created from
  # @mentions and quotes on other users' threads land.
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

  # Mirror parent inbox agent assignments onto the auto-created
  # sub-inbox so the same team sees mentions without manual setup.
  def copy_inbox_members_to(target_inbox)
    user_ids = inbox.inbox_members.pluck(:user_id)
    return if user_ids.blank?

    target_inbox.add_members(user_ids)
  end

  def subscribe
    # ref https://developers.facebook.com/docs/threads/webhooks
    HTTParty.post(
      "https://graph.threads.net/v1.0/#{threads_user_id}/subscribed_apps",
      query: {
        subscribed_fields: %w[replies mentions quotes],
        access_token: access_token
      }
    )
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  def unsubscribe
    HTTParty.delete(
      "https://graph.threads.net/v1.0/#{threads_user_id}/subscribed_apps",
      query: { access_token: access_token }
    )
    true
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  # Delegates to the refresh service so long-lived tokens auto-renew
  # when they approach expiry (within 10 days and at least 24h old).
  def access_token
    Threads::RefreshOauthTokenService.new(channel: self).access_token
  end
end
