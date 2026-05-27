class Reports::BotMetricsEventIngestionService
  EVENT_NAMES = %w[
    external_bot_conversation
    external_bot_response
    external_bot_resolved
    external_bot_handoff
  ].freeze

  EVENT_NAME_BY_TYPE = {
    'conversation' => 'external_bot_conversation',
    'conversation_started' => 'external_bot_conversation',
    'response' => 'external_bot_response',
    'response_sent' => 'external_bot_response',
    'resolved' => 'external_bot_resolved',
    'conversation_resolved' => 'external_bot_resolved',
    'handoff' => 'external_bot_handoff',
    'handoff_to_human' => 'external_bot_handoff'
  }.freeze

  class UnsupportedEventError < StandardError
    attr_reader :payload

    def initialize(payload)
      @payload = payload
      super('Unsupported bot metric event')
    end
  end

  pattr_initialize [:account!, :payloads!]

  def perform
    normalized_payloads.map { |payload| create_event(payload) }
  end

  private

  def normalized_payloads
    Array(payloads).map do |payload|
      raw_payload = payload.respond_to?(:to_unsafe_h) ? payload.to_unsafe_h : payload
      raw_payload.with_indifferent_access
    end
  end

  def create_event(payload)
    event_time = event_time(payload)

    ReportingEvent.create!(
      account: account,
      name: event_name(payload),
      value: event_value(payload),
      inbox_id: payload[:inbox_id],
      user_id: payload[:user_id],
      conversation_id: safe_integer_id(payload[:conversation_id]),
      event_start_time: event_time,
      event_end_time: event_time,
      created_at: event_time,
      updated_at: event_time
    )
  end

  def event_name(payload)
    name = payload[:name].presence || EVENT_NAME_BY_TYPE[payload[:event_type].to_s]
    return name if EVENT_NAMES.include?(name)

    raise UnsupportedEventError, payload
  end

  def event_value(payload)
    value = payload[:value].presence || 1
    value.to_f.positive? ? value.to_f : 1
  end

  def event_time(payload)
    return Time.zone.at(payload[:created_at].to_i) if payload[:created_at].to_s.match?(/\A\d+\z/)

    Time.zone.parse(payload[:created_at].presence || payload[:event_time].presence || Time.current.to_s)
  rescue ArgumentError
    Time.current
  end

  def safe_integer_id(value)
    return if value.blank?

    id = value.to_i
    id.positive? && id <= 2_147_483_647 ? id : nil
  end
end
