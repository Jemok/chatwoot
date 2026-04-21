class Demo::Simulators::InboundMessageService < Demo::Simulators::BaseService
  def perform!
    inbox = pick_inbox(queue_kind: 'dm')
    raise 'No DM inbox available' unless inbox

    name = payload[:contact_name].presence || demo_name
    phone = payload[:phone].presence || demo_phone
    body = payload[:body].presence || 'Hi, I need help with my account please.'

    _, contact_inbox = find_or_create_contact_inbox(inbox, name: name, phone: phone)
    conv = build_conversation(contact_inbox, source_type: 'dm')
    msg = add_incoming_message(conv, body)
    { conversation_id: conv.display_id, message_id: msg.id, inbox: inbox.name }
  end

  private

  def demo_name
    %w[Aisha Brenda Carlos Daniel Esther].sample + ' ' + %w[Kim Patel Mwangi Adeyemi Lopez].sample
  end

  def demo_phone
    "+2547#{rand(10_000_000..99_999_999)}"
  end
end
