# Locks a conversation as a different user (or as the current user) so the
# presenter can demonstrate collision prevention from a second browser session.
class Demo::Simulators::CollisionService < Demo::Simulators::BaseService
  def perform!
    conv = account.conversations.find(payload[:conversation_id]) if payload[:conversation_id].present?
    conv ||= account.conversations.where.not(id: nil).order(id: :desc).first
    raise 'No conversation available — create one first' unless conv

    # Pick another agent if available; else lock as the current user
    other_user = account.users.where.not(id: user&.id).first || user
    raise 'No user available' unless other_user

    lock = ConversationLock.acquire!(conversation: conv, user: other_user, ttl_seconds: 5.minutes)
    { conversation_id: conv.display_id, locked_by_user_id: other_user.id, locked_by_name: other_user.name, expires_at: lock.expires_at }
  end
end
