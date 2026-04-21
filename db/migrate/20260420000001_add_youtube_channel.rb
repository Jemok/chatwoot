class AddYoutubeChannel < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_youtube do |t|
      t.string :access_token, null: false
      t.string :refresh_token
      t.datetime :expires_at, null: false
      t.integer :account_id, null: false
      t.string :youtube_channel_id, null: false
      t.string :channel_title
      t.datetime :last_polled_at
      t.timestamps
    end

    add_index :channel_youtube, :youtube_channel_id, unique: true
  end
end
