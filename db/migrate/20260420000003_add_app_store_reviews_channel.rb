class AddAppStoreReviewsChannel < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_app_store_reviews do |t|
      t.string :app_id, null: false
      t.string :issuer_id, null: false
      t.string :key_id, null: false
      t.text :p8_private_key, null: false
      t.string :vendor_name
      t.datetime :last_polled_at
      t.integer :account_id, null: false
      t.timestamps
    end

    add_index :channel_app_store_reviews, :app_id, unique: true
  end
end
