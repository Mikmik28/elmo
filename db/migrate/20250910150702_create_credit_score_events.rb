class CreateCreditScoreEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_score_events, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :reason, null: false
      t.integer :delta, null: false
      t.jsonb :meta

      t.timestamps
    end

    # Add indexes (user_id index already created by reference)
    add_index :credit_score_events, :reason
    add_index :credit_score_events, :created_at
    add_index :credit_score_events, [ :user_id, :reason ]
    add_index :credit_score_events, [ :user_id, :created_at ]

    # Add constraints
    add_check_constraint :credit_score_events, "reason IN ('on_time_payment', 'overdue', 'utilization', 'kyc_bonus', 'default')", name: "credit_score_events_valid_reason"
  end
end
