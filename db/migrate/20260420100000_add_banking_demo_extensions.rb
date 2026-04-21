class AddBankingDemoExtensions < ActiveRecord::Migration[7.1]
  def change
    # F1/F2: queue + source separation
    add_column :inboxes, :queue_kind, :string
    add_column :inboxes, :source_type, :string
    add_column :conversations, :source_type, :string
    add_index :conversations, :source_type

    # F5: banking profile fields stored on contact (full account_number lives encrypted in jsonb)
    add_column :contacts, :banking_attributes, :jsonb, default: {}, null: false

    # F4 + F10: policy violation + denial audit log (hide/delete + window blocks + denied actions)
    create_table :policy_violation_logs do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id
      t.bigint :conversation_id
      t.bigint :inbox_id
      t.string :policy, null: false        # whatsapp_24h, facebook_7d, denied_action, suspicious_login
      t.string :action_attempted
      t.text :details
      t.string :request_ip
      t.timestamps
      t.index :account_id
      t.index :conversation_id
      t.index :policy
    end

    # F6: cross-channel identity link suggestions (supervisor-approved merge)
    create_table :identity_link_suggestions do |t|
      t.bigint :account_id, null: false
      t.bigint :primary_contact_id, null: false
      t.bigint :candidate_contact_id, null: false
      t.string :match_key, null: false     # phone_number / email / identifier
      t.string :match_value
      t.integer :status, default: 0, null: false  # 0 pending, 1 approved, 2 dismissed
      t.bigint :decided_by_user_id
      t.datetime :decided_at
      t.timestamps
      t.index :account_id
      t.index [:primary_contact_id, :candidate_contact_id, :match_key], unique: true,
                                                                        name: 'idx_identity_link_suggestions_unique'
    end

    # F7: in-conversation lock to prevent collision / enforce single active responder
    create_table :conversation_locks do |t|
      t.bigint :conversation_id, null: false
      t.bigint :user_id, null: false
      t.bigint :account_id, null: false
      t.datetime :expires_at, null: false
      t.boolean :supervisor_takeover, default: false, null: false
      t.timestamps
      t.index :conversation_id, unique: true
      t.index :user_id
      t.index :expires_at
    end
  end
end
