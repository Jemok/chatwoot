# Logs an unauthorized/denied action attempt for the security audit feed (#10).
class Demo::Simulators::DeniedActionService < Demo::Simulators::BaseService
  def perform!
    log = PolicyViolationLog.create!(
      account_id: account.id,
      user_id: user&.id,
      policy: 'denied_action',
      action_attempted: payload[:action_attempted].presence || 'GET /api/v1/accounts/:id/reports/admin_only',
      details: payload[:details].presence || 'Agent attempted to access supervisor-only endpoint',
      request_ip: payload[:ip].presence || '203.0.113.42'
    )
    { log_id: log.id, policy: log.policy, action: log.action_attempted }
  end
end
