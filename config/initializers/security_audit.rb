# Banking demo (Phase 2 #4): security audit hooks. Funnels failed logins,
# throttled requests and Pundit denials into the existing PolicyViolationLog
# (single security/audit feed).

# 1. Failed authentication — fires for every Warden failure (bad password,
#    expired token, MFA failure, …) before any rack-attack throttle kicks in.
Warden::Manager.before_failure do |env, opts|
  request = ActionDispatch::Request.new(env)
  email = request.params.dig('email') || request.params.dig('user', 'email')
  account = User.find_by(email: email)&.accounts&.first if email.present?
  PolicyViolationLog.create!(
    account_id: account&.id || Account.first&.id,
    user_id: nil,
    policy: 'suspicious_login',
    action_attempted: "#{request.request_method} #{request.path}",
    details: "Failed auth (#{opts[:message] || 'invalid'}) for #{email || 'unknown'}",
    request_ip: request.remote_ip
  )
rescue StandardError => e
  Rails.logger.warn("[SecurityAudit] failed-login log error: #{e.message}")
end

# 2. Rack::Attack throttle/blocklist — every match writes an audit entry.
ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _req_id, payload|
  next unless payload[:request]

  req = payload[:request]
  PolicyViolationLog.create!(
    account_id: Account.first&.id,
    policy: 'suspicious_login',
    action_attempted: "#{req.request_method} #{req.path} (throttled)",
    details: "Rack::Attack matched #{payload[:match_data]&.dig(:matched) || 'rule'} for IP #{req.ip}",
    request_ip: req.ip
  )
rescue StandardError => e
  Rails.logger.warn("[SecurityAudit] throttle log error: #{e.message}")
end
