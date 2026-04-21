class AddIndexPolicyViolationLogsOnAccountCreatedAt < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :policy_violation_logs,
              [:account_id, :created_at],
              name: 'index_policy_violation_logs_on_account_created_at',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
