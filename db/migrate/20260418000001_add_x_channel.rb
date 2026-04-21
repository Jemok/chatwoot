class AddXChannel < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_x do |t|
      t.string :access_token, null: false
      t.string :access_token_secret, null: false
      t.integer :account_id, null: false
      t.string :x_user_id, null: false
      t.string :username
      t.timestamps
    end

    add_index :channel_x, :x_user_id, unique: true
  end
end
