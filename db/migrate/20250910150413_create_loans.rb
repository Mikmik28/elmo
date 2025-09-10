class CreateLoans < ActiveRecord::Migration[8.0]
  def change
    create_table :loans, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.integer :amount_cents, null: false
      t.integer :term_days, null: false
      t.string :product, null: false
      t.string :state, default: "pending", null: false
      t.date :due_on
      t.integer :principal_outstanding_cents, default: 0, null: false
      t.integer :interest_accrued_cents, default: 0, null: false
      t.integer :penalty_accrued_cents, default: 0, null: false
      t.decimal :apr, precision: 10, scale: 4

      t.timestamps
    end

    # Add indexes for performance and queries (user_id index already created by reference)
    add_index :loans, :state
    add_index :loans, :due_on
    add_index :loans, [ :user_id, :state ]
    add_index :loans, [ :state, :due_on ]

    # Add constraints
    add_check_constraint :loans, "amount_cents > 0", name: "loans_amount_positive"
    add_check_constraint :loans, "term_days > 0", name: "loans_term_positive"
    add_check_constraint :loans, "product IN ('micro', 'extended', 'longterm')", name: "loans_valid_product"
    add_check_constraint :loans, "state IN ('pending', 'approved', 'disbursed', 'paid', 'overdue', 'defaulted')", name: "loans_valid_state"
    add_check_constraint :loans, "(product != 'longterm') OR (term_days IN (270, 365))", name: "loans_longterm_term_validation"
  end
end
