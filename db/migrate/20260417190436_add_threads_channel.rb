class AddThreadsChannel < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_threads do |t|
      t.string :access_token, null: false
      t.datetime :expires_at, null: false
      t.integer :account_id, null: false
      t.string :threads_user_id, null: false
      t.string :username
      t.timestamps
    end

    add_index :channel_threads, :threads_user_id, unique: true
  end
end
