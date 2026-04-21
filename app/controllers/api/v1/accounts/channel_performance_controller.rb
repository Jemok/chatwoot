# Banking demo (Phase 2 #3): real-time per-channel performance dashboard.
# Aggregates open / resolved counts, avg first-response and resolution times
# from existing reporting_events — no new tables.
class Api::V1::Accounts::ChannelPerformanceController < Api::V1::Accounts::BaseController
  WINDOW = 24.hours

  def index
    since = WINDOW.ago
    inboxes = Current.account.inboxes.includes(:channel).to_a

    rows = inboxes.map do |inbox|
      conv_scope = inbox.conversations
      open_count = conv_scope.where(status: :open).count
      resolved_today = conv_scope.where(status: :resolved).where('updated_at > ?', since).count
      pending_24h = conv_scope.where(status: :open).where('waiting_since < ?', 24.hours.ago).count

      first_resp = ReportingEvent.where(account_id: Current.account.id, inbox_id: inbox.id, name: 'first_response')
                                 .where('created_at > ?', since).average(:value).to_f
      resolution = ReportingEvent.where(account_id: Current.account.id, inbox_id: inbox.id, name: 'conversation_resolved')
                                 .where('created_at > ?', since).average(:value).to_f

      {
        inbox_id: inbox.id,
        inbox_name: inbox.name,
        channel_type: inbox.channel_type,
        queue_kind: inbox.queue_kind,
        source_type: inbox.source_type,
        open: open_count,
        resolved_24h: resolved_today,
        pending_over_24h: pending_24h,
        avg_first_response_seconds: first_resp.round(0),
        avg_resolution_seconds: resolution.round(0)
      }
    end

    by_kind = rows.group_by { |r| r[:queue_kind] || 'dm' }.transform_values do |group|
      {
        open: group.sum { |r| r[:open] },
        resolved_24h: group.sum { |r| r[:resolved_24h] },
        pending_over_24h: group.sum { |r| r[:pending_over_24h] }
      }
    end

    render json: {
      window_hours: WINDOW.in_hours.to_i,
      by_inbox: rows.sort_by { |r| -r[:open] },
      by_queue_kind: by_kind,
      totals: {
        open: rows.sum { |r| r[:open] },
        resolved_24h: rows.sum { |r| r[:resolved_24h] },
        pending_over_24h: rows.sum { |r| r[:pending_over_24h] }
      }
    }
  end
end
