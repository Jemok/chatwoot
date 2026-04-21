class Demo::Simulators::MentionService < Demo::Simulators::BaseService
  def perform!
    inbox = pick_inbox(queue_kind: 'mentions')
    raise 'No mentions inbox available (e.g. "<Page> - Mentions")' unless inbox

    name = payload[:mentioner_name].presence || 'External Tweeter'
    body = payload[:body].presence || '@YourBank your app keeps logging me out, please help!'

    _, contact_inbox = find_or_create_contact_inbox(inbox, name: name)
    conv = build_conversation(
      contact_inbox,
      source_type: 'mentions',
      additional_attributes: { type: 'mention', simulated: true }
    )
    msg = add_incoming_message(conv, body)
    { conversation_id: conv.display_id, message_id: msg.id, inbox: inbox.name }
  end
end
