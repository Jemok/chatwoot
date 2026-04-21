# Logs a synthetic failed-login event (used in Phase 2 security dashboard,
# but exposed here so Phase 1 demo coverage is complete).
class Demo::Simulators::FailedLoginService < Demo::Simulators::BaseService
  def perform!
    log = PolicyViolationLog.create!(
      account_id: account.id,
      user_id: nil,
      policy: 'suspicious_login',
      action_attempted: 'POST /auth/sign_in',
      details: payload[:details].presence || "5 failed logins from #{payload[:ip] || '198.51.100.7'} in 60s",
      request_ip: payload[:ip].presence || '198.51.100.7'
    )
    { log_id: log.id, policy: log.policy }
  end
end
