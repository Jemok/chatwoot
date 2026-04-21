class AddBankingDemoShiftLifecycle < ActiveRecord::Migration[7.0]
  def change
    add_column :shifts, :recurrence, :string, default: 'once', null: false
    add_column :shifts, :weekday, :integer
    add_column :shifts, :timezone, :string
    add_column :shifts, :recurrence_group_id, :string
    add_index :shifts, :recurrence_group_id

    add_column :account_users, :suspended_at, :datetime
    add_column :account_users, :suspended_reason, :string
    add_index :account_users, :suspended_at
  end
end
