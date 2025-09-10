class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.uuid :target_id
      t.string :target_type
      t.string :action, null: false
      t.jsonb :changeset
      t.string :ip
      t.text :user_agent

      t.timestamps
    end

    # Add indexes (user_id index already created by reference)
    add_index :audit_logs, :target_type
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
    add_index :audit_logs, [ :target_type, :target_id ]
    add_index :audit_logs, [ :user_id, :action ]
    add_index :audit_logs, [ :user_id, :created_at ]
  end
end
