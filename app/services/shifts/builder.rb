# Expands a "weekly" shift definition into N upcoming Shift rows so admins can
# schedule a recurring rota with a single API call. Single-shift creation
# remains in the ShiftsController#create path.
class Shifts::Builder
  DEFAULT_WEEKS_AHEAD = 4

  # weekdays: array of integer wdays (0=Sunday..6=Saturday)
  # start_time / end_time: 'HH:MM' strings interpreted in `timezone`
  # rubocop:disable Metrics/ParameterLists
  def initialize(account:, user:, weekdays:, start_time:, end_time:, timezone:, weeks_ahead: DEFAULT_WEEKS_AHEAD)
    @account = account
    @user = user
    @weekdays = Array(weekdays).map(&:to_i).uniq
    @start_time = start_time
    @end_time = end_time
    @timezone = timezone.presence || Time.zone.name
    @weeks_ahead = weeks_ahead
  end
  # rubocop:enable Metrics/ParameterLists

  def perform!
    group_id = SecureRandom.uuid
    rows = build_rows(group_id)
    Shift.insert_all!(rows) if rows.any? # rubocop:disable Rails/SkipsModelValidations
    Shift.where(recurrence_group_id: group_id).order(:starts_at).to_a
  end

  private

  # rubocop:disable Metrics/MethodLength
  def build_rows(group_id)
    Time.use_zone(@timezone) do
      today = Time.zone.today
      (0...(@weeks_ahead * 7)).filter_map do |offset|
        date = today + offset
        next unless @weekdays.include?(date.wday)

        starts = Time.zone.parse("#{date} #{@start_time}")
        ends = Time.zone.parse("#{date} #{@end_time}")
        next if starts.nil? || ends.nil? || ends <= starts

        {
          account_id: @account.id,
          user_id: @user.id,
          starts_at: starts,
          ends_at: ends,
          status: 'scheduled',
          recurrence: 'weekly',
          weekday: date.wday,
          timezone: @timezone,
          recurrence_group_id: group_id,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    end
  end
  # rubocop:enable Metrics/MethodLength
end
