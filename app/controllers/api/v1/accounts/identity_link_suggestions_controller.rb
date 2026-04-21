class Api::V1::Accounts::IdentityLinkSuggestionsController < Api::V1::Accounts::BaseController
  before_action :ensure_supervisor!, only: [:approve]
  before_action :set_suggestion, only: [:approve, :dismiss]

  def index
    @suggestions = IdentityLinkSuggestion.where(account_id: Current.account.id, status: :pending)
                                         .includes(:primary_contact, :candidate_contact)
                                         .order(id: :desc)
                                         .limit(50)
    render json: @suggestions.map { |s| serialize(s) }
  end

  def approve
    @suggestion.approve!(Current.user)
    render json: { success: true, suggestion: serialize(@suggestion) }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  def dismiss
    @suggestion.dismiss!(Current.user)
    render json: { success: true, suggestion: serialize(@suggestion) }
  end

  private

  def set_suggestion
    @suggestion = IdentityLinkSuggestion.where(account_id: Current.account.id).find(params[:id])
  end

  def ensure_supervisor!
    return if Current.account_user&.administrator?

    render json: { error: 'Supervisor/administrator access required for identity merge' }, status: :forbidden
  end

  def serialize(s)
    {
      id: s.id,
      status: s.status,
      match_key: s.match_key,
      match_value: s.match_value,
      primary_contact: contact_blob(s.primary_contact),
      candidate_contact: contact_blob(s.candidate_contact),
      created_at: s.created_at,
      decided_at: s.decided_at,
      decided_by_user_id: s.decided_by_user_id
    }
  end

  def contact_blob(c)
    return nil unless c

    { id: c.id, name: c.name, phone_number: c.phone_number, email: c.email,
      identifier: c.identifier, channels: c.contact_inboxes.includes(:inbox).map { |ci| ci.inbox.name } }
  end
end
