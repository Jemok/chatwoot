class Demo::Simulators::OffensiveCommentService < Demo::Simulators::BaseService
  OFFENSIVE_SAMPLES = [
    'You guys are absolute thieves, I want my money back NOW!!!',
    'This bank is a SCAM, everyone stay away!!!',
    'Worst service ever, your CEO should be fired!!'
  ].freeze

  def perform!
    inbox = pick_inbox(queue_kind: 'public')
    raise 'No public-queue inbox available (e.g. "<Page> - Public")' unless inbox

    name = payload[:commenter_name].presence || 'Angry Visitor'
    body = payload[:body].presence || OFFENSIVE_SAMPLES.sample

    _, contact_inbox = find_or_create_contact_inbox(inbox, name: name)
    conv = build_conversation(
      contact_inbox,
      source_type: 'comments',
      additional_attributes: { type: 'public_comment', simulated: true, flagged: 'offensive' }
    )
    msg = add_incoming_message(conv, body)

    # Auto-tag with a 'needs-moderation' label if the label exists in the account
    if (label = account.labels.find_by(title: 'needs-moderation'))
      conv.add_labels([label.title])
    else
      account.labels.create!(title: 'needs-moderation', color: '#FF0000')
      conv.add_labels(['needs-moderation'])
    end

    { conversation_id: conv.display_id, message_id: msg.id, inbox: inbox.name, flagged: true }
  end
end
