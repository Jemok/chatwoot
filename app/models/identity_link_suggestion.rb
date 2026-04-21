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
