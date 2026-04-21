# Banking demo (Feature 8): Enforced automatic routing.
# - accounts.enforced_routing_enabled flips the whole feature on/off per account.
# - automation_rules.enforced marks individual rules that should bypass agent
#   round-robin and be applied unconditionally before generic assignment.
# Both columns are tiny boolean adds to small admin-config tables, so a plain
# migration (no concurrently) is sufficient.
class AddEnforcedRoutingFields < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :enforced_routing_enabled, :boolean, default: false, null: false
    add_column :automation_rules, :enforced, :boolean, default: false, null: false
  end
end
