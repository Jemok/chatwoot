class Demo::Simulators::PublicCommentService < Demo::Simulators::BaseService
  def perform!
    inbox = pick_inbox(queue_kind: 'public')
    raise 'No public-queue inbox available (e.g. "<Page> - Public")' unless inbox

    name = payload[:commenter_name].presence || 'Public Visitor'
    body = payload[:body].presence || 'Hi @YourBank — when does the new branch in Westlands open?'

    _, contact_inbox = find_or_create_contact_inbox(inbox, name: name)
    conv = build_conversation(
      contact_inbox,
      source_type: 'comments',
      additional_attributes: { type: 'public_comment', simulated: true }
    )
    msg = add_incoming_message(conv, body)
    { conversation_id: conv.display_id, message_id: msg.id, inbox: inbox.name }
  end
end
