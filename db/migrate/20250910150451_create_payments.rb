class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments, id: :uuid do |t|
      t.references :loan, null: false, foreign_key: true, type: :uuid
      t.integer :amount_cents, null: false
      t.string :state, default: "pending", null: false
      t.string :gateway_ref
      t.datetime :posted_at
      t.jsonb :gateway_payload

      t.timestamps
    end

    # Add indexes (loan_id index already created by reference)
    add_index :payments, :state
    add_index :payments, :posted_at
    add_index :payments, :gateway_ref, unique: true
    add_index :payments, [ :loan_id, :state ]

    # Add constraints
    add_check_constraint :payments, "amount_cents > 0", name: "payments_amount_positive"
    add_check_constraint :payments, "state IN ('pending', 'cleared', 'failed')", name: "payments_valid_state"
  end
end
