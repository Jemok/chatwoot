# Banking demo (#10): cross-channel index of public-comment messages for the
# Moderation Center UI. Returns outgoing+incoming messages attached to
# conversations whose source_type=='public_comment', with channel pill +
# moderation state so admins can bulk hide/delete.
class Api::V1::Accounts::PublicCommentsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  PER_PAGE_DEFAULT = 25
  PER_PAGE_MAX = 100

  def index
    scope = Message.joins(:conversation)
                   .where(account_id: Current.account.id)
                   .where(conversations: { source_type: 'public_comment' })
    scope = scope.joins(:inbox).where(inboxes: { channel_type: params[:channel_type] }) if params[:channel_type].present?
    scope = scope.where("content_attributes->>'moderated' = 'true'") if params[:status] == 'moderated'
    scope = scope.where("(content_attributes->>'moderated') IS NULL OR content_attributes->>'moderated' = 'false'") if params[:status] == 'open'

    total = scope.count
    records = scope.includes(:inbox, :conversation).order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: records.map { |m| serialize(m) },
      meta: { page: page, per_page: per_page, total_count: total }
    }
  end

  private

  def check_authorization
    authorize Message, :moderate?
  end

  def page
    [params.fetch(:page, 1).to_i, 1].max
  end

  def per_page
    value = params.fetch(:per_page, PER_PAGE_DEFAULT).to_i
    value = PER_PAGE_DEFAULT if value <= 0
    [value, PER_PAGE_MAX].min
  end

  def serialize(message)
    attrs = message.content_attributes || {}
    {
      id: message.id,
      conversation_id: message.conversation_id,
      conversation_display_id: message.conversation&.display_id,
      inbox_id: message.inbox_id,
      inbox_name: message.inbox&.name,
      channel_type: message.inbox&.channel_type,
      sender_id: message.sender_id,
      sender_type: message.sender_type,
      content: message.content,
      original_content: attrs['original_content'],
      moderated: attrs['moderated'] == true || attrs['moderated'] == 'true',
      moderation: attrs['moderation'],
      created_at: message.created_at
    }
  end
end
