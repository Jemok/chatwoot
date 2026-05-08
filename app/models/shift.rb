# == Schema Information
#
# Table name: shifts
#
#  id                  :bigint           not null, primary key
#  ends_at             :datetime         not null
#  recurrence          :string           default("once"), not null
#  starts_at           :datetime         not null
#  status              :string           default("scheduled"), not null
#  timezone            :string
#  weekday             :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  recurrence_group_id :string
#  user_id             :bigint           not null
#
# Indexes
#
#  index_shifts_on_account_id_and_user_id_and_starts_at  (account_id,user_id,starts_at)
#  index_shifts_on_recurrence_group_id                   (recurrence_group_id)
#  index_shifts_on_status                                (status)
#
class Shift < ApplicationRecord
  belongs_to :account
  belongs_to :user

  STATUSES = %w[scheduled active completed cancelled].freeze
  RECURRENCES = %w[once weekly].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :recurrence, inclusion: { in: RECURRENCES }
  validates :starts_at, :ends_at, presence: true
  validate :end_after_start

  scope :current, -> { where('starts_at <= :now AND ends_at >= :now', now: Time.current).where.not(status: 'cancelled') }
  scope :ending_between, ->(from, to) { where(ends_at: from..to).where.not(status: 'cancelled') }
  scope :starting_between, ->(from, to) { where(starts_at: from..to).where.not(status: 'cancelled') }

  def self.user_on_duty?(user, account)
    return true if account.nil? || user.nil?

    Shift.current.where(account_id: account.id, user_id: user.id).exists?
  end

  # Bypass when the account has no shifts configured at all (allow legacy users)
  def self.shift_enforcement_active?(account)
    Shift.where(account_id: account&.id).exists?
  end

  private

  def end_after_start
    errors.add(:ends_at, 'must be after starts_at') if ends_at && starts_at && ends_at <= starts_at
  end
end
