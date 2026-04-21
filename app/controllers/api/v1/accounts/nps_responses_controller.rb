# Banking demo (Phase 2 #6): NPS responses + report.
# - POST creates a response (open to authenticated agents for demo;
#   in production wire to a survey link or webhook)
# - GET returns the rolling NPS over the requested window
class Api::V1::Accounts::NpsResponsesController < Api::V1::Accounts::BaseController
  def index
    days = params.fetch(:days, 30).to_i
    since = days.days.ago
    scope = NpsResponse.where(account_id: Current.account.id).where('created_at > ?', since)
    total = scope.count
    promoters = scope.promoters.count
    passives = scope.passives.count
    detractors = scope.detractors.count
    nps = total.zero? ? 0 : (((promoters - detractors).to_f / total) * 100).round(1)

    payload = {
      window_days: days,
      total: total,
      nps: nps,
      breakdown: { promoters: promoters, passives: passives, detractors: detractors },
      by_inbox: scope.group(:inbox_id).count,
      recent: scope.order(id: :desc).limit(10).map { |r| serialize(r) }
    }
    payload[:trend] = trend_series(scope, params[:group_by]) if params[:group_by].present?
    payload[:by_agent] = by_agent_series(scope) if params[:by_agent].present?
    payload[:comments] = comments_page(scope) if params[:comments].present? && Current.account_user&.administrator?
    render json: payload
  end

  def create
    response = NpsResponse.create!(
      account_id: Current.account.id,
      contact_id: params[:contact_id],
      conversation_id: params[:conversation_id],
      inbox_id: params[:inbox_id],
      score: params[:score],
      comment: params[:comment]
    )
    render json: serialize(response)
  end

  private

  def trend_series(scope, group_by)
    bucket = group_by == 'week' ? "date_trunc('week', created_at)" : "date_trunc('day', created_at)"
    rows = scope.group(Arel.sql(bucket)).select(
      "#{bucket} as bucket",
      'COUNT(*) FILTER (WHERE score >= 9) AS promoters',
      'COUNT(*) FILTER (WHERE score BETWEEN 7 AND 8) AS passives',
      'COUNT(*) FILTER (WHERE score <= 6) AS detractors'
    ).order(Arel.sql(bucket))
    rows.map do |row|
      total = row.promoters + row.passives + row.detractors
      nps = total.zero? ? 0 : (((row.promoters - row.detractors).to_f / total) * 100).round(1)
      { bucket: row.bucket, promoters: row.promoters, passives: row.passives, detractors: row.detractors, total: total, nps: nps }
    end
  end

  def by_agent_series(scope)
    scope.joins('LEFT JOIN conversations ON conversations.id = nps_responses.conversation_id')
         .group('conversations.assignee_id').count
  end

  def comments_page(scope)
    scope.where.not(comment: [nil, '']).order(id: :desc).limit(50).map { |r| serialize(r) }
  end

  def serialize(r)
    {
      id: r.id,
      score: r.score,
      category: r.category,
      comment: r.comment,
      contact_id: r.contact_id,
      conversation_id: r.conversation_id,
      inbox_id: r.inbox_id,
      created_at: r.created_at
    }
  end
end
