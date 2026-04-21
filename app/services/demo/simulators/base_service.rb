# Base for demo simulators. Subclasses implement `perform!` and may use the
# helpers below to create real conversations/messages/contacts via existing
# Chatwoot builders.
class Demo::Simulators::BaseService
  attr_reader :account, :user, :payload

  def initialize(account:, user:, payload: {})
    @account = account
    @user = user
    @payload = (payload || {}).with_indifferent_access
  end

  def perform!
    raise NotImplementedError
  end

  protected

  # Picks an inbox for the simulator. Honors payload[:inbox_id], else falls back
  # to the first inbox matching the requested queue_kind or the default inbox.
  def pick_inbox(queue_kind: nil, channel_type: nil)
    scope = account.inboxes
    return scope.find(payload[:inbox_id]) if payload[:inbox_id].present?

    scope = scope.where(queue_kind: queue_kind) if queue_kind
    scope = scope.where(channel_type: channel_type) if channel_type
    scope.first || account.inboxes.first
  end

  # Find or create a contact + ContactInbox. Mirrors ContactInboxWithContactBuilder
  # but without forcing a remote source_id (we synthesize one for demo).
  def find_or_create_contact_inbox(inbox, name:, phone: nil, identifier: nil)
    source_id = identifier || "demo-#{SecureRandom.hex(6)}"
    contact = account.contacts.where(phone_number: phone).first if phone.present?
    contact ||= account.contacts.create!(name: name, phone_number: phone, identifier: identifier)
    contact_inbox = ContactInbox.find_or_create_by!(contact: contact, inbox: inbox, source_id: source_id)
    [contact, contact_inbox]
  end

  def build_conversation(contact_inbox, additional_attributes: {}, source_type: nil)
    Conversation.create!(
      account_id: account.id,
      inbox_id: contact_inbox.inbox_id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id,
      additional_attributes: additional_attributes,
      source_type: source_type
    )
  end

  def add_incoming_message(conversation, content)
    conversation.messages.create!(
      account_id: account.id,
      inbox_id: conversation.inbox_id,
      content: content,
      message_type: :incoming,
      sender: conversation.contact,
      content_type: 'text'
    )
  end
end
