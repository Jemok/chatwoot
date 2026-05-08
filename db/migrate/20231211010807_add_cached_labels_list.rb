class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string
    Conversation.reset_column_information
    Conversation.find_each do |conversation|
      conversation.update_columns(
        cached_label_list: conversation.label_list.join(',')
      )
    end
  end
end
