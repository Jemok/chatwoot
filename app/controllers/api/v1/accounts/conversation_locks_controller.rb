# Single-active-responder lock API. Frontend acquires on conversation open,
# heartbeats every ~60s, releases on close/send. Supervisors may force takeover.
class Api::V1::Accounts::ConversationLocksController < Api::V1::Accounts::BaseController
  before_action :set_conversation
  before_action :authorize_lock_action

  def show
    lock = active_lock
    render json: lock_payload(lock)
  end

  def create
    lock = ConversationLock.acquire!(conversation: @conversation, user: Current.user)
    render json: lock_payload(lock)
  rescue ConversationLock::Conflict => e
    render json: { conflict: true, lock: lock_payload(e.lock), error: e.message }, status: :conflict
  end

  def heartbeat
    lock = active_lock
    if lock && lock.user_id == Current.user.id
      lock.update!(expires_at: Time.current + ConversationLock::DEFAULT_TTL)
      render json: lock_payload(lock)
    else
      render json: { error: 'No active lock held by current user' }, status: :not_found
    end
  end

  def takeover
    lock = ConversationLock.acquire!(conversation: @conversation, user: Current.user, supervisor_takeover: true)
    render json: lock_payload(lock)
  end

  def destroy
    ConversationLock.release!(conversation: @conversation, user: Current.user)
    render json: { released: true }
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
  end

  def authorize_lock_action
    authorize @conversation, :"#{action_name}?", policy_class: ConversationLockPolicy
  end

  def active_lock
    ConversationLock.active.find_by(conversation_id: @conversation.id)
  end

  def lock_payload(lock)
    return { locked: false } unless lock

    {
      locked: true,
      conversation_id: lock.conversation_id,
      user_id: lock.user_id,
      user_name: lock.user.name,
      expires_at: lock.expires_at.to_i,
      supervisor_takeover: lock.supervisor_takeover,
      held_by_me: lock.user_id == Current.user.id
    }
  end
end
