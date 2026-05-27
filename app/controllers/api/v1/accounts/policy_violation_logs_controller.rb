class Api::V1::Accounts::PolicyViolationLogsController < Api::V1::Accounts::BaseController
  skip_before_action :authenticate_access_token!, only: [:create]
  skip_before_action :validate_bot_access_token!, only: [:create]
  skip_before_action :authenticate_user!, only: [:create]

  before_action :check_authorization, unless: :audit_log_secret_authentic?

  PER_PAGE_DEFAULT = 25
  PER_PAGE_MAX = 100

  def index
    scope = PolicyViolationLog.where(account_id: Current.account.id)
    scope = apply_filters(scope)

    total = scope.count
    records = scope.includes(:conversation, :inbox).order(id: :desc).offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: records.map { |r| serialize(r) },
      meta: { page: page, per_page: per_page, total_count: total }
    }
  end

  def create
    record = PolicyViolationLog.create!(permitted_payload.merge(account: Current.account))

    render json: { data: serialize(record) }, status: :created
  end

  private

  def serialize(record)
    record.as_json.merge(
      conversation_display_id: record.conversation&.display_id,
      inbox_name: record.inbox&.name,
      inbox_channel_type: record.inbox&.channel_type
    )
  end

  def check_authorization
    authorize PolicyViolationLog, "#{action_name}?".to_sym
  end

  def audit_log_secret_authentic?
    return @audit_log_secret_authentic if defined?(@audit_log_secret_authentic)

    expected_secret = ENV.fetch('AUDIT_LOG_SECRET', nil)
    provided_secret = request.headers['X-Audit-Log-Secret'].to_s

    @audit_log_secret_authentic = audit_log_secret_configured?(expected_secret) && provided_secret.present? &&
                                  secure_secret_compare(provided_secret, expected_secret)
  end

  def audit_log_secret_configured?(secret)
    secret.present? && secret != 'replace_with_secure_shared_secret'
  end

  def secure_secret_compare(provided_secret, expected_secret)
    provided_digest = OpenSSL::Digest::SHA256.hexdigest(provided_secret)
    expected_digest = OpenSSL::Digest::SHA256.hexdigest(expected_secret)

    ActiveSupport::SecurityUtils.secure_compare(provided_digest, expected_digest)
  end

  def permitted_payload
    payload = params[:policy_violation_log].presence || params

    {
      policy: payload[:policy],
      action_attempted: payload[:action_attempted],
      details: payload[:details],
      request_ip: payload[:request_ip],
      conversation_id: payload[:conversation_id],
      inbox_id: payload[:inbox_id],
      user_id: payload[:user_id]
    }
  end

  def apply_filters(scope)
    scope = scope.where(policy: requested_policies) if requested_policies.any?
    scope = scope.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
    scope = scope.joins(:inbox).where(inboxes: { channel_type: params[:channel_type] }) if params[:channel_type].present?
    scope = scope.where('policy_violation_logs.created_at >= ?', parse_time(params[:from])) if params[:from].present?
    scope = scope.where('policy_violation_logs.created_at <= ?', parse_time(params[:to])) if params[:to].present?
    scope
  end

  # Banking demo: do NOT name this `policies` — Pundit::Authorization uses an
  # instance method of the same name as its per-request policy cache, and
  # overriding it with an Array blows up `authorize` with
  # `TypeError: no implicit conversion of Class into Integer`.
  def requested_policies
    Array(params[:policy]).compact_blank
  end

  def page
    [params.fetch(:page, 1).to_i, 1].max
  end

  def per_page
    value = params.fetch(:per_page, PER_PAGE_DEFAULT).to_i
    value = PER_PAGE_DEFAULT if value <= 0
    [value, PER_PAGE_MAX].min
  end

  def parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
