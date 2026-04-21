class AddLinkedinChannel < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_linkedin do |t|
      t.string :access_token, null: false
      t.string :refresh_token
      t.datetime :expires_at, null: false
      t.integer :account_id, null: false
      t.string :linkedin_user_urn, null: false
      t.string :organization_urn
      t.string :username
      t.timestamps
    end

    add_index :channel_linkedin, :linkedin_user_urn, unique: true
  end
end
