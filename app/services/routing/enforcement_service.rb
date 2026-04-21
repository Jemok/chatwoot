# Banking demo (Feature 8): apply enforced automation rules at conversation
# creation time, before the generic round-robin assignment kicks in.
# - When the account flag is off, this is a no-op.
# - Otherwise we walk the account's enforced rules in id order, run the
#   existing condition matcher, apply the existing action service for the
#   first match, and stamp `route_reason` on the conversation so the UI can
#   show a "Routed by Rule X" chip.
class Routing::EnforcementService
  def initialize(conversation)
    @conversation = conversation
    @account = conversation.account
  end

  def perform
    return unless @account.enforced_routing_enabled
    return if @conversation.additional_attributes&.dig('route_reason').present?

    rule = matching_rule
    return unless rule

    AutomationRules::ActionService.new(rule, @account, @conversation).perform
    stamp_route_reason!(rule)
  end

  private

  def matching_rule
    @account.automation_rules.active.where(enforced: true, event_name: 'conversation_created').order(:id).find do |rule|
      AutomationRules::ConditionsFilterService.new(rule, @conversation, {}).perform.present?
    end
  end

  def stamp_route_reason!(rule)
    attrs = (@conversation.additional_attributes || {}).merge(
      'route_reason' => { 'rule_id' => rule.id, 'rule_name' => rule.name, 'enforced' => true }
    )
    @conversation.update_columns(additional_attributes: attrs)
  end
end
