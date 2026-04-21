class AddBankingDemoPhase2Tables < ActiveRecord::Migration[7.1]
  def change
    create_table :nps_responses do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :conversation_id
      t.bigint :inbox_id
      t.integer :score, null: false
      t.text :comment
      t.timestamps
    end
    add_index :nps_responses, [:account_id, :created_at]
    add_index :nps_responses, :conversation_id

    create_table :shifts do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, default: 'scheduled', null: false
      t.timestamps
    end
    add_index :shifts, [:account_id, :user_id, :starts_at]
    add_index :shifts, :status
  end
end
