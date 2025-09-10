class CreatePromoCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :promo_codes, id: :uuid do |t|
      t.string :code, null: false
      t.string :kind, null: false
      t.integer :value_cents
      t.decimal :percent_off, precision: 5, scale: 2
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    # Add indexes
    add_index :promo_codes, :code, unique: true
    add_index :promo_codes, :active
    add_index :promo_codes, :ends_at
    add_index :promo_codes, [ :active, :ends_at ]

    # Add constraints
    add_check_constraint :promo_codes, "kind IN ('referral', 'discount')", name: "promo_codes_valid_kind"
    add_check_constraint :promo_codes, "(value_cents IS NOT NULL) OR (percent_off IS NOT NULL)", name: "promo_codes_has_value"
  end
end
