# Banking demo: shift CRUD + on-duty status + recurring weekly schedules.
# Pundit-gated via ShiftPolicy.
class Api::V1::Accounts::ShiftsController < Api::V1::Accounts::BaseController
  SHIFT_TZ = ENV.fetch('BANK_DEMO_SHIFT_TZ', 'Africa/Nairobi')

  # Banking demo: surface validation errors as JSON 422 so the UI form can
  # render them (e.g. "ends_at must be after starts_at", overlap checks).
  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  rescue_from ArgumentError do |e|
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def index
    authorize Shift
    scope = Shift.where(account_id: Current.account.id)
    scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
    render json: scope.order(starts_at: :desc).limit(200).map { |s| serialize(s) }
  end

  def create
    authorize Shift
    s = Shift.create!(
      account_id: Current.account.id,
      user_id: params[:user_id],
      starts_at: parse_local(params[:starts_at]),
      ends_at: parse_local(params[:ends_at]),
      status: params[:status].presence || 'scheduled',
      timezone: SHIFT_TZ
    )
    render json: serialize(s)
  end

  def update
    s = Shift.where(account_id: Current.account.id).find(params[:id])
    authorize s
    attrs = {}
    attrs[:starts_at] = parse_local(params[:starts_at]) if params[:starts_at]
    attrs[:ends_at] = parse_local(params[:ends_at]) if params[:ends_at]
    attrs[:status] = params[:status] if params[:status]
    s.update!(attrs)
    render json: serialize(s)
  end

  def destroy
    s = Shift.where(account_id: Current.account.id).find(params[:id])
    authorize s
    s.destroy!
    head :no_content
  end

  # POST /shifts/bulk_create_recurring
  # body: { user_id, weekdays: [1,2,3,4,5], start_time: '09:00', end_time: '17:00', weeks_ahead: 4 }
  def bulk_create_recurring
    authorize Shift, :bulk_create_recurring?
    user = Current.account.users.find(params[:user_id])
    rows = Shifts::Builder.new(
      account: Current.account,
      user: user,
      weekdays: params[:weekdays] || [],
      start_time: params[:start_time],
      end_time: params[:end_time],
      timezone: SHIFT_TZ,
      weeks_ahead: (params[:weeks_ahead].presence || Shifts::Builder::DEFAULT_WEEKS_AHEAD).to_i
    ).perform!
    PolicyViolationLog.create!(
      account_id: Current.account.id,
      user_id: Current.user&.id,
      policy: 'user_lifecycle',
      action_attempted: 'shift_bulk_create',
      details: "Generated #{rows.size} weekly shifts for user_id=#{user.id} weekdays=#{params[:weekdays]}",
      request_ip: request.remote_ip
    )
    render json: { created: rows.size, shifts: rows.map { |s| serialize(s) } }
  end

  def on_duty
    authorize Shift, :on_duty?
    status = Shifts::EnforcementService.new(user: Current.user, account: Current.account).status
    render json: {
      enforcement_active: Shift.shift_enforcement_active?(Current.account),
      on_duty: Shift.user_on_duty?(Current.user, Current.account),
      status: status,
      current_shift_count: Shift.current.where(account_id: Current.account.id).count,
      shift_timezone: SHIFT_TZ,
      my_current_shift: Shift.current.find_by(account_id: Current.account.id, user_id: Current.user&.id)&.then { |s| serialize(s) }
    }
  end

  private

  def parse_local(value)
    return nil if value.blank?

    Time.use_zone(SHIFT_TZ) { Time.zone.parse(value.to_s) }
  end

  def format_local(time)
    return nil if time.nil?

    time.in_time_zone(SHIFT_TZ).strftime('%Y-%m-%d %H:%M')
  end

  def serialize(s)
    {
      id: s.id,
      user_id: s.user_id,
      user_name: s.user&.name,
      starts_at: s.starts_at,
      ends_at: s.ends_at,
      starts_at_local: format_local(s.starts_at),
      ends_at_local: format_local(s.ends_at),
      timezone: s.timezone || SHIFT_TZ,
      status: s.status,
      recurrence: s.recurrence,
      recurrence_group_id: s.recurrence_group_id,
      is_current: s.starts_at <= Time.current && s.ends_at >= Time.current && s.status != 'cancelled'
    }
  end
end
