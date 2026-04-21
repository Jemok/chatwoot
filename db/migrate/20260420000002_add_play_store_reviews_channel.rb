class AddPlayStoreReviewsChannel < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_play_store_reviews do |t|
      t.string :package_name, null: false
      t.string :service_account_email
      t.text :credentials_json, null: false
      t.datetime :last_polled_at
      t.integer :account_id, null: false
      t.timestamps
    end
    add_index :channel_play_store_reviews, :package_name, unique: true
  end
end
