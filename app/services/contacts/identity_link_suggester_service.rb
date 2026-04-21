# Auto-suggests cross-channel identity links when a new contact's phone
# matches another contact's phone_number or banking_attributes['linked_phone'].
# Uniqueness on contacts.phone_number per account is enforced — so realistic
# matches occur via the linked_phone jsonb hint (set during channel onboarding
# or by demo simulators).
class Contacts::IdentityLinkSuggesterService
  def self.run_for(contact)
    new(contact).run
  end

  def initialize(contact)
    @contact = contact
    @account = contact.account
  end

  def run
    phone = effective_phone
    return if phone.blank?

    candidates = find_candidates(phone)
    candidates.each do |candidate|
      next if candidate.id == @contact.id

      IdentityLinkSuggestion.find_or_create_by!(
        account_id: @account.id,
        primary_contact_id: [@contact.id, candidate.id].min,
        candidate_contact_id: [@contact.id, candidate.id].max,
        match_key: 'phone_number'
      ) { |s| s.match_value = phone }
    end
  rescue StandardError => e
    Rails.logger.warn("IdentityLinkSuggester failed for contact #{@contact.id}: #{e.message}")
  end

  private

  def effective_phone
    @contact.phone_number.presence || (@contact.banking_attributes || {})['linked_phone']
  end

  def find_candidates(phone)
    @account.contacts
            .where("phone_number = :p OR banking_attributes->>'linked_phone' = :p", p: phone)
            .where.not(id: @contact.id)
            .limit(5)
  end
end
