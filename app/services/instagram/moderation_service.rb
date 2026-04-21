# Banking demo (#8): platform-side moderation for Instagram comments.
# Same pattern as Facebook::ModerationService — IG Graph supports
# POST /{ig-comment-id}?hide=true and DELETE /{ig-comment-id}.
class Instagram::ModerationService
  attr_reader :message, :user, :error

  def initialize(message:, user:, action:)
    @message = message
    @user = user
    @action = action.to_s
  end

  def perform!
    raise 'Unsupported action' unless %w[hide unhide delete].include?(@action)
    raise 'Message has no platform source_id' if message.source_id.blank?

    @ok = simulated? || call_graph
    update_local_state!
    log_audit(@ok, simulated: simulated?)
    { ok: @ok, simulated: simulated?, action: @action, source_id: message.source_id, error: @error }
  end

  private

  def simulated?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('MODERATION_SIMULATED', 'true'))
  end

  def channel
    @channel ||= message.conversation.inbox.channel
  end

  def access_token
    channel.try(:access_token) || channel.try(:page_access_token)
  end

  def call_graph
    response = HTTParty.send(http_verb, graph_url, query: graph_query)
    parsed = response.parsed_response
    if parsed.is_a?(Hash) && parsed['error']
      @error = parsed['error']['message']
      false
    else
      true
    end
  rescue StandardError => e
    @error = e.message
    false
  end

  def http_verb
    @action == 'delete' ? :delete : :post
  end

  def graph_url
    "https://graph.facebook.com/v19.0/#{message.source_id}"
  end

  def graph_query
    base = { access_token: access_token }
    return base if @action == 'delete'

    base.merge(hide: @action == 'hide')
  end

  def update_local_state!
    attrs = (message.content_attributes || {}).deep_dup
    attrs['original_content'] ||= message.content
    attrs['moderation'] = { 'action' => @action, 'by_user_id' => user&.id, 'at' => Time.current.iso8601, 'simulated' => simulated? }
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
      action_attempted: "instagram.#{@action}",
      details: "Message ##{message.id} #{@action} on IG (success=#{ok}, simulated=#{simulated})#{@error ? " err=#{@error}" : ''}"
    )
  end
end
