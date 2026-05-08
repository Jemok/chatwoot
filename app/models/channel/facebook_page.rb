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
  before_destroy :unsubscribe
  def name
    'Facebook'
  end

  # Override the `has_one :inbox` association to deterministically return
  # the DM inbox when multiple inboxes (Public / Mentions / Visitor Posts)
  # share the same channel row. Prefers the inbox explicitly tagged with
  # queue_kind='dm'; falls back to the oldest untagged inbox for legacy rows.
  def inbox
    rel = sibling_inboxes
    rel.find_by(queue_kind: 'dm') || rel.where(queue_kind: nil).order(:id).first || rel.order(:id).first
  end
  alias dm_inbox inbox
  # Returns the public inbox for feed/comment conversations.
  # Created automatically when the Facebook page channel is set up.
  def public_inbox
    find_companion_inbox(source_type: 'comments', name_suffix: 'Public')
  end

  def ensure_public_inbox
    return if public_inbox.present?
    return unless dm_inbox

    Inbox.create!(
      channel: self,
      account: dm_inbox.account,
      name: "#{dm_inbox.name} - Public",
      queue_kind: 'public'
    )
  end

  # Returns the mentions inbox where conversations created from
  # @Page mentions (on other users' posts/comments) land.
  def mentions_inbox
    find_companion_inbox(queue_kind: 'mentions', source_type: 'mentions', name_suffix: 'Mentions')
  end

  def ensure_mentions_inbox
    return if mentions_inbox.present?
    return unless dm_inbox

    Inbox.create!(
      channel: self,
      account: dm_inbox.account,
      name: "#{dm_inbox.name} - Mentions",
      queue_kind: 'mentions'
    )
  end

  # Returns the visitor-posts inbox where conversations are created when
  # a user posts directly on the page's timeline.
  def visitor_posts_inbox
    find_companion_inbox(source_type: 'wall_posts', name_suffix: 'Visitor Posts')
  end

  def ensure_visitor_posts_inbox
    return if visitor_posts_inbox.present?
    return unless dm_inbox

    Inbox.create!(
      channel: self,
      account: dm_inbox.account,
      name: "#{dm_inbox.name} - Visitor Posts",
      queue_kind: 'public'
    )
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

  private

  def find_companion_inbox(queue_kind: nil, source_type: nil, name_suffix: nil)
    scope = sibling_inboxes
    scope = scope.where(queue_kind: queue_kind) if queue_kind
    scope = scope.where(source_type: source_type) if source_type

    return scope.first if scope.first.present?

    base_name = dm_inbox&.name
    return unless base_name && name_suffix

    sibling_inboxes.find_by(name: "#{base_name} - #{name_suffix}")
  end

  def sibling_inboxes
    Inbox.where(channel_type: 'Channel::FacebookPage', channel_id: id)
  end
end
