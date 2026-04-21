# Creates two contacts (in separate inboxes) sharing a phone number, then
# generates a pending IdentityLinkSuggestion for the supervisor to approve.
class Demo::Simulators::IdentityLinkService < Demo::Simulators::BaseService
  def perform!
    phone = payload[:phone].presence || "+2547#{rand(10_000_000..99_999_999)}"
    inbox_a = account.inboxes.where(queue_kind: 'dm').first
    inbox_b = account.inboxes.where(queue_kind: 'dm').offset(1).first || inbox_a
    raise 'Need at least one inbox' unless inbox_a

    name = payload[:contact_name].presence || 'Mary Cross-Channel'
    # Use a fresh phone if collision, to keep demo idempotent
    phone = "+2547#{rand(10_000_000..99_999_999)}" while account.contacts.exists?(phone_number: phone)
    contact_a = account.contacts.create!(name: "#{name} (WA)", phone_number: phone)
    # Sibling contact: same phone is what we want to *suggest* linking, but Contact has a
    # unique-per-account guard on phone — so we store the candidate's phone in
    # banking_attributes['linked_phone'] and use a synthetic identifier instead.
    contact_b = account.contacts.create!(
      name: "#{name} (FB)",
      identifier: "demo-link-#{SecureRandom.hex(4)}",
      banking_attributes: { 'linked_phone' => phone }
    )

    ContactInbox.find_or_create_by!(contact: contact_a, inbox: inbox_a, source_id: "demo-a-#{SecureRandom.hex(4)}")
    ContactInbox.find_or_create_by!(contact: contact_b, inbox: inbox_b, source_id: "demo-b-#{SecureRandom.hex(4)}")

    suggestion = IdentityLinkSuggestion.find_or_create_by!(
      account_id: account.id,
      primary_contact_id: contact_a.id,
      candidate_contact_id: contact_b.id,
      match_key: 'phone_number'
    ) { |s| s.match_value = phone }

    { suggestion_id: suggestion.id, primary_contact_id: contact_a.id, candidate_contact_id: contact_b.id, match_value: phone }
  end
end
