# Banking demo control panel — admin-only endpoint that triggers honest in-app
# simulations of inbound traffic, policy violations, identity-link suggestions,
# collision events, and security events. Each `kind` is dispatched to a small
# service under `app/services/demo/simulators/` that uses real Chatwoot
# builders/models so the resulting state is genuine (no fake records).
class Api::V1::Accounts::Demo::ControlPanelController < Api::V1::Accounts::BaseController
  before_action :ensure_administrator!

  KINDS = %w[
    inbound_message
    public_comment
    mention
    offensive_comment
    old_whatsapp
    old_facebook
    identity_link
    collision
    denied_action
    failed_login
    shift_end_force_logout
  ].freeze

  def simulate
    kind = params[:kind].to_s
    return render_invalid_kind unless KINDS.include?(kind)

    service_class = "Demo::Simulators::#{kind.camelize}Service".constantize
    result = service_class.new(account: Current.account, user: Current.user, payload: payload_params).perform!
    render json: { success: true, kind: kind, result: result }
  rescue StandardError => e
    Rails.logger.error("[Demo::ControlPanel] #{kind} failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    render json: { success: false, kind: kind, error: e.message }, status: :unprocessable_entity
  end

  def overview
    render json: {
      kinds: KINDS,
      counts: {
        inboxes: Current.account.inboxes.count,
        conversations: Current.account.conversations.count,
        contacts: Current.account.contacts.count,
        identity_link_suggestions: IdentityLinkSuggestion.where(account_id: Current.account.id).pending.count,
        policy_violations_24h: PolicyViolationLog.where(account_id: Current.account.id).where('created_at > ?', 24.hours.ago).count
      },
      recent_violations: PolicyViolationLog.where(account_id: Current.account.id).order(id: :desc).limit(10).as_json
    }
  end

  private

  def ensure_administrator!
    render json: { error: 'Administrator access required' }, status: :forbidden unless Current.account_user&.administrator?
  end

  def payload_params
    params.fetch(:payload, {}).permit!.to_h
  end

  def render_invalid_kind
    render json: { success: false, error: "Unknown demo kind. Allowed: #{KINDS.join(', ')}" }, status: :bad_request
  end
end
