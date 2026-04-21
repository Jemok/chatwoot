# Creates a WhatsApp (or Twilio-WA) conversation whose last incoming message
# is older than 24 hours, so the agent reply attempt triggers the
# WhatsApp 24h policy enforcement (#4).
class Demo::Simulators::OldWhatsappService < Demo::Simulators::BaseService
  def perform!
    inbox = account.inboxes.where(channel_type: %w[Channel::Whatsapp Channel::TwilioSms]).first
    raise 'No WhatsApp/Twilio inbox available' unless inbox

    name = payload[:contact_name].presence || 'Linda Otieno'
    phone = payload[:phone].presence || "+2547#{rand(10_000_000..99_999_999)}"

    _, contact_inbox = find_or_create_contact_inbox(inbox, name: name, phone: phone)
    conv = build_conversation(contact_inbox, source_type: 'dm')
    msg = add_incoming_message(conv, 'Hi, I lost my card yesterday — please help!')

    aged_at = 26.hours.ago
    msg.update_columns(created_at: aged_at, updated_at: aged_at)
    conv.update_columns(last_activity_at: aged_at, waiting_since: aged_at)

    { conversation_id: conv.display_id, inbox: inbox.name, last_incoming_at: aged_at, hours_ago: 26 }
  end
end
