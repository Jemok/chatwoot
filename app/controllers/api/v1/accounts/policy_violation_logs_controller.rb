class Api::V1::Accounts::PolicyViolationLogsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

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

  private

  def serialize(record)
    record.as_json.merge(
      conversation_display_id: record.conversation&.display_id,
      inbox_name: record.inbox&.name,
      inbox_channel_type: record.inbox&.channel_type
    )
  end

  def check_authorization
    authorize PolicyViolationLog, :index?
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
