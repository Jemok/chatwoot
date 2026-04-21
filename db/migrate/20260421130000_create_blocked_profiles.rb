class CreateBlockedProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :blocked_profiles do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :channel_type, null: false
      t.string :platform_user_id, null: false
      t.bigint :contact_id
      t.string :reason
      t.datetime :blocked_until
      t.bigint :blocked_by_user_id
      t.timestamps
    end

    add_index :blocked_profiles,
              [:account_id, :channel_type, :platform_user_id],
              unique: true,
              name: 'idx_blocked_profiles_on_account_channel_platform_uid'
    add_index :blocked_profiles, :contact_id
  end
end
