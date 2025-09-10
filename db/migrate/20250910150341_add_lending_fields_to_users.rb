class AddLendingFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :full_name, :string
    add_column :users, :credit_limit_cents, :integer, default: 0, null: false
    add_column :users, :current_score, :integer, default: 600, null: false
    add_column :users, :referral_code, :string
    add_column :users, :kyc_status, :string, default: "pending", null: false
    add_column :users, :kyc_payload, :jsonb

    # Add indexes for performance
    add_index :users, :phone, unique: true
    add_index :users, :referral_code, unique: true
    add_index :users, :kyc_status
    add_index :users, :credit_limit_cents
  end
end
