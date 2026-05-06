# == Schema Information
#
# Table name: channel_instagram
#
#  id           :bigint           not null, primary key
#  access_token :string           not null
#  expires_at   :datetime         not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :integer          not null
#  instagram_id :string           not null
#
# Indexes
#
#  index_channel_instagram_on_instagram_id  (instagram_id) UNIQUE
#
class Channel::Instagram < ApplicationRecord
  include Channelable
  include Reauthorizable
  self.table_name = 'channel_instagram'

  # TODO: Remove guard once encryption keys become mandatory (target 3-4 releases out).
  encrypts :access_token if Chatwoot.encryption_configured?

  AUTHORIZATION_ERROR_THRESHOLD = 1

  validates :access_token, presence: true
  validates :instagram_id, uniqueness: true, presence: true

  after_create_commit :subscribe
  after_create_commit :ensure_public_inbox
  after_create_commit :ensure_mentions_inbox
  # Re-register webhook subscriptions whenever the token changes
  # (e.g. OAuth reauthorization) so newly-granted fields like `comments`
  # get picked up without a manual resubscribe.
  after_update_commit :subscribe, if: :saved_change_to_access_token?
  before_destroy :unsubscribe

  def name
    'Instagram'
  end

  # Override the `has_one :inbox` association to deterministically return
  # the DM inbox when multiple inboxes (Public / Mentions) share the same
  # channel row. Prefers the inbox explicitly tagged with queue_kind='dm';
  # falls back to the oldest untagged row for legacy installs.
  def inbox
    rel = Inbox.where(channel_type: 'Channel::Instagram', channel_id: id)
    rel.find_by(queue_kind: 'dm') || rel.where(queue_kind: nil).order(:id).first || rel.order(:id).first
  end

  # Returns the public inbox for feed/comment conversations.
  # Created automatically when the Instagram channel is set up.
  def public_inbox
    sibling_inboxes.find_by(queue_kind: 'public')
  end

  def ensure_public_inbox
    return if public_inbox.present?
    return unless inbox&.account

    sub_inbox = Inbox.create!(channel: self, account: inbox.account, name: "#{inbox.name} - Public", queue_kind: 'public')
    copy_inbox_members_to(sub_inbox)
  end

  # Returns the mentions inbox where conversations created from
  # @mentions (on other users' posts/comments) land.
  def mentions_inbox
    sibling_inboxes.find_by(queue_kind: 'mentions')
  end

  def ensure_mentions_inbox
    return if mentions_inbox.present?
    return unless inbox&.account

    sub_inbox = Inbox.create!(channel: self, account: inbox.account, name: "#{inbox.name} - Mentions", queue_kind: 'mentions')
    copy_inbox_members_to(sub_inbox)
  end

  # Mirror the parent inbox's agent assignments onto the auto-created
  # sub-inbox so the same team sees comments/mentions without manual setup.
  def copy_inbox_members_to(target_inbox)
    user_ids = inbox.inbox_members.pluck(:user_id)
    return if user_ids.blank?

    target_inbox.add_members(user_ids)
  end

  def create_contact_inbox(instagram_id, name)
    @contact_inbox = ::ContactInboxWithContactBuilder.new({
                                                            source_id: instagram_id,
                                                            inbox: inbox,
                                                            contact_attributes: { name: name }
                                                          }).perform
  end

  def subscribe
    # ref https://developers.facebook.com/docs/instagram-platform/webhooks#enable-subscriptions
    HTTParty.post(
      "https://graph.instagram.com/v22.0/#{instagram_id}/subscribed_apps",
      query: {
        subscribed_fields: %w[messages message_reactions messaging_seen comments],
        access_token: access_token
      }
    )
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  def unsubscribe
    HTTParty.delete(
      "https://graph.instagram.com/v22.0/#{instagram_id}/subscribed_apps",
      query: {
        access_token: access_token
      }
    )
    true
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  def access_token
    Instagram::RefreshOauthTokenService.new(channel: self).access_token
  end

  private

  def sibling_inboxes
    Inbox.where(channel_type: 'Channel::Instagram', channel_id: id)
  end
end
