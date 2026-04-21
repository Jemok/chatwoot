# Banking demo (#10): internal viewer for deleted + moderated message content.
# Returns the current (replaced) text plus the original_content preserved by
# stock destroy / moderation services. Admin-only (authorized via PolicyViolationLogPolicy).
class Api::V1::Accounts::ModeratedMessagesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  PER_PAGE_DEFAULT = 25
  PER_PAGE_MAX = 100

  def index
    scope = Message.where(account_id: Current.account.id)
                   .where("content_attributes->>'deleted' = 'true' OR content_attributes->>'moderated' = 'true'")
    scope = apply_filters(scope)

    total = scope.count
    records = scope.order(updated_at: :desc).offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: records.map { |m| serialize(m) },
      meta: { page: page, per_page: per_page, total_count: total }
    }
  end

  private

  def check_authorization
    authorize PolicyViolationLog, :index?
  end

  def apply_filters(scope)
    scope = scope.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope = scope.where(sender_id: params[:user_id]) if params[:user_id].present?
    scope = scope.joins(:inbox).where(inboxes: { channel_type: params[:channel_type] }) if params[:channel_type].present?
    scope = scope.where('messages.updated_at >= ?', parse_time(params[:from])) if params[:from].present?
    scope = scope.where('messages.updated_at <= ?', parse_time(params[:to])) if params[:to].present?
    scope
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

  def serialize(m)
    attrs = m.content_attributes || {}
    {
      id: m.id,
      conversation_id: m.conversation_id,
      conversation_display_id: m.conversation&.display_id,
      inbox_id: m.inbox_id,
      inbox_name: m.inbox&.name,
      inbox_channel_type: m.inbox&.channel_type,
      sender_id: m.sender_id,
      sender_type: m.sender_type,
      message_type: m.message_type,
      current_content: m.content,
      original_content: attrs['original_content'],
      deleted: !!attrs['deleted'],
      moderated: !!attrs['moderated'],
      moderation: attrs['moderation'],
      updated_at: m.updated_at,
      created_at: m.created_at
    }
  end
end
