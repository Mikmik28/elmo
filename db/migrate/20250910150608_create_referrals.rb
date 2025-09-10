class CreateReferrals < ActiveRecord::Migration[8.0]
  def change
    create_table :referrals, id: :uuid do |t|
      t.references :referrer, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :referee, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.string :status, default: "pending", null: false
      t.references :promo_code, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end

    # Add indexes (referrer_id, referee_id, promo_code_id indexes already created by references)
    add_index :referrals, :status
    add_index :referrals, [ :referrer_id, :referee_id ], unique: true

    # Add constraints
    add_check_constraint :referrals, "status IN ('pending', 'rewarded')", name: "referrals_valid_status"
    add_check_constraint :referrals, "referrer_id != referee_id", name: "referrals_no_self_referral"
  end
end
