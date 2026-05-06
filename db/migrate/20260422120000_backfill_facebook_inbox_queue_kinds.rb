class BackfillFacebookInboxQueueKinds < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    Inbox.where(channel_type: 'Channel::FacebookPage').find_each do |inbox|
      kind = case inbox.name
             when /\s-\sPublic\z/ then 'public'
             when /\s-\sMentions\z/ then 'mentions'
             when /\s-\sVisitor Posts\z/ then 'visitor_posts'
             else 'dm'
             end
      inbox.update_columns(queue_kind: kind) if inbox.queue_kind != kind
    end
  end

  def down
    # No-op: leaving queue_kind in place is safe.
  end
end
