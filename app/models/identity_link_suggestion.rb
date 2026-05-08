# == Schema Information
#
# Table name: identity_link_suggestions
#
#  id                   :bigint           not null, primary key
#  decided_at           :datetime
#  match_key            :string           not null
#  match_value          :string
#  status               :integer          default("pending"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  candidate_contact_id :bigint           not null
#  decided_by_user_id   :bigint
#  primary_contact_id   :bigint           not null
#
# Indexes
#
#  idx_identity_link_suggestions_unique           (primary_contact_id,candidate_contact_id,match_key) UNIQUE
#  index_identity_link_suggestions_on_account_id  (account_id)
#
class IdentityLinkSuggestion < ApplicationRecord
  belongs_to :account
  belongs_to :primary_contact, class_name: 'Contact'
  belongs_to :candidate_contact, class_name: 'Contact'
  belongs_to :decided_by_user, class_name: 'User', optional: true

  enum status: { pending: 0, approved: 1, dismissed: 2 }

  validates :match_key, presence: true
  validate :different_contacts

  def approve!(user)
    transaction do
      ContactMergeAction.new(
        account: account,
        base_contact: primary_contact,
        mergee_contact: candidate_contact
      ).perform
      update!(status: :approved, decided_by_user: user, decided_at: Time.current)
    end
  end

  def dismiss!(user)
    update!(status: :dismissed, decided_by_user: user, decided_at: Time.current)
  end

  private

  def different_contacts
    errors.add(:candidate_contact_id, 'must differ from primary_contact_id') if primary_contact_id == candidate_contact_id
  end
end
