class Webhooks::ThreadsController < ActionController::API
  include MetaTokenVerifyConcern

  def events
    Rails.logger.info('Threads webhook received events')
    payload = params.to_unsafe_hash.except(:controller, :action)
    Rails.logger.info("THREADS_WEBHOOK_RAW: #{payload.to_json}")

    entries = extract_entries(payload)
    if entries.present?
      ::Webhooks::ThreadsEventsJob.perform_later(entries)
      render json: :ok
    else
      Rails.logger.warn("Unrecognized threads webhook payload: object=#{payload['object'].inspect} topic=#{payload['topic'].inspect}")
      head :unprocessable_entity
    end
  end

  private

  def extract_entries(payload)
    return Array(payload[:entry]) if payload['object'].to_s.casecmp('threads').zero?
    return [] unless payload['values'].is_a?(Array)

    # Legacy Threads webhook shape: { topic:, target_id:, values: [{ value:, field: }] }
    changes = payload['values'].map { |v| { 'field' => v['field'], 'value' => v['value'] } }
    threads_user_id = changes.dig(0, 'value', 'root_post', 'owner_id') || payload['target_id']
    return [] if threads_user_id.blank?

    [{ 'id' => threads_user_id.to_s, 'time' => payload['time'], 'changes' => changes }]
  end

  def valid_token?(token)
    token == GlobalConfigService.load('THREADS_VERIFY_TOKEN', '')
  end
end
