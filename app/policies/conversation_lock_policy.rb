# Banking demo (#7): Pundit gate for the single-active-responder lock API.
# - show / create / heartbeat / destroy: any agent who can view the conversation.
# - takeover: administrators only (supervisor override).
class ConversationLockPolicy < ApplicationPolicy
  def show?
    conversation_visible?
  end

  def create?
    conversation_visible?
  end

  def heartbeat?
    conversation_visible?
  end

  def destroy?
    conversation_visible?
  end

  def takeover?
    @account_user&.administrator?
  end

  private

  def conversation_visible?
    return false if record.blank?

    ConversationPolicy.new(@user_context, record).show?
  end
end
