# == Schema Information
#
# Table name: channel_facebook_pages
#
#  id                :integer          not null, primary key
#  page_access_token :string           not null
#  user_access_token :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#  instagram_id      :string
#  page_id           :string           not null
#
# Indexes
#
#  index_channel_facebook_pages_on_page_id                 (page_id)
#  index_channel_facebook_pages_on_page_id_and_account_id  (page_id,account_id) UNIQUE
#

class Channel::FacebookPage < ApplicationRecord
  include Channelable
  include Reauthorizable

  # TODO: Remove guard once encryption keys become mandatory (target 3-4 releases out).
  if Chatwoot.encryption_configured?
    encrypts :page_access_token
    encrypts :user_access_token
  end

  self.table_name = 'channel_facebook_pages'

  validates :page_id, uniqueness: { scope: :account_id }

  after_create_commit :subscribe
  after_create_commit :ensure_public_inbox
  after_create_commit :ensure_mentions_inbox
  after_create_commit :ensure_visitor_posts_inbox
  before_destroy :unsubscribe

  def name
    'Facebook'
  end

  # A Facebook Page channel owns multiple inboxes (DM + companion queues for
  # Public comments, Mentions, Visitor Posts). `has_one :inbox` from
  # Channelable is not deterministic when there are multiple rows, so we
  # always resolve the DM inbox by queue_kind. Falls back to the lowest-id
  # inbox on this channel for pre-migration data that hasn't been tagged.
  def dm_inbox
    account = Account.find_by(id: account_id)
    return unless account

    scope = account.inboxes.where(channel: self)
    scope.find_by(queue_kind: 'dm') || scope.order(:id).first
  end

  # Name to use when computing companion inbox names. Always derived from the
  # DM inbox so the naming is stable regardless of creation order.
  def base_inbox_name
    dm_inbox&.name
  end

  # Returns the public inbox for feed/comment conversations.
  # Created automatically when the Facebook page channel is set up.
  def public_inbox
    base = base_inbox_name
    return unless base

    dm_inbox.account.inboxes.find_by(channel: self, name: "#{base} - Public")
  end

  def ensure_public_inbox
    return if public_inbox.present?
    return unless dm_inbox

    Inbox.create!(channel: self, account: dm_inbox.account, name: "#{base_inbox_name} - Public")
  end

  # Returns the mentions inbox where conversations created from
  # @Page mentions (on other users' posts/comments) land.
  def mentions_inbox
    base = base_inbox_name
    return unless base

    dm_inbox.account.inboxes.find_by(channel: self, name: "#{base} - Mentions")
  end

  def ensure_mentions_inbox
    return if mentions_inbox.present?
    return unless dm_inbox

    Inbox.create!(channel: self, account: dm_inbox.account, name: "#{base_inbox_name} - Mentions")
  end

  # Returns the visitor-posts inbox where conversations are created when
  # a user posts directly on the page's timeline.
  def visitor_posts_inbox
    base = base_inbox_name
    return unless base

    dm_inbox.account.inboxes.find_by(channel: self, name: "#{base} - Visitor Posts")
  end

  def ensure_visitor_posts_inbox
    return if visitor_posts_inbox.present?
    return unless dm_inbox

    Inbox.create!(channel: self, account: dm_inbox.account, name: "#{base_inbox_name} - Visitor Posts")
  end

  def create_contact_inbox(instagram_id, name)
    @contact_inbox = ::ContactInboxWithContactBuilder.new({
                                                            source_id: instagram_id,
                                                            inbox: dm_inbox,
                                                            contact_attributes: { name: name }
                                                          }).perform
  end

  def subscribe
    graph = Koala::Facebook::API.new(page_access_token)
    graph.put_connections(page_id, 'subscribed_apps', {
                            subscribed_fields: %w[messages message_deliveries message_echoes message_reads messaging_handovers feed mention],
                            include_values: true
                          })
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  def unsubscribe
    Facebook::Messenger::Subscriptions.unsubscribe(access_token: page_access_token)
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end
end
