# Banking demo (#10): platform-side moderation for TikTok public comments.
# TikTok's Comment Management API is gated behind Business approval, so this
# service runs in simulated mode by default — local state updates + audit.
class Tiktok::ModerationService
  attr_reader :message, :user, :error

  def initialize(message:, user:, action:)
    @message = message
    @user = user
    @action = action.to_s
  end

  def perform!
    raise 'Unsupported action' unless %w[hide unhide delete].include?(@action)

    @ok = true # Always simulated — TikTok API not reachable in demo context
    update_local_state!
    log_audit(@ok, simulated: true)
    { ok: @ok, simulated: true, action: @action, source_id: message.source_id, error: @error }
  end

  private

  def update_local_state!
    attrs = (message.content_attributes || {}).deep_dup
    attrs['original_content'] ||= message.content
    attrs['moderation'] = { 'action' => @action, 'by_user_id' => user&.id, 'at' => Time.current.iso8601, 'simulated' => true }
    new_content = case @action
                  when 'delete' then I18n.t('conversations.messages.deleted')
                  when 'hide'   then I18n.t('conversations.messages.hidden_by_moderation', default: '[Hidden by moderation]')
                  when 'unhide' then attrs['original_content']
                  end
    message.update!(content: new_content, content_attributes: attrs.merge('moderated' => @action != 'unhide'))
  end

  def log_audit(ok, simulated:)
    PolicyViolationLog.create!(
      account_id: message.account_id,
      user_id: user&.id,
      conversation_id: message.conversation_id,
      inbox_id: message.inbox_id,
      policy: 'moderation_action',
      action_attempted: "tiktok.#{@action}",
      details: "Message ##{message.id} #{@action} on TikTok (success=#{ok}, simulated=#{simulated})"
    )
  end
end
