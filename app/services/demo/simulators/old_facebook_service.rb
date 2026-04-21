# Creates a Facebook DM conversation whose last incoming message is older
# than 7 days so the agent reply attempt triggers the FB 7d policy (#4).
class Demo::Simulators::OldFacebookService < Demo::Simulators::BaseService
  def perform!
    inbox = account.inboxes.where(channel_type: 'Channel::FacebookPage', queue_kind: 'dm').first
    raise 'No Facebook DM inbox available' unless inbox

    name = payload[:contact_name].presence || 'Peter Wanjiru'

    _, contact_inbox = find_or_create_contact_inbox(inbox, name: name)
    conv = build_conversation(contact_inbox, source_type: 'dm')
    msg = add_incoming_message(conv, 'Hello, I had a question last week — still waiting for help.')

    aged_at = 8.days.ago
    msg.update_columns(created_at: aged_at, updated_at: aged_at)
    conv.update_columns(last_activity_at: aged_at, waiting_since: aged_at)

    { conversation_id: conv.display_id, inbox: inbox.name, last_incoming_at: aged_at, days_ago: 8 }
  end
end
