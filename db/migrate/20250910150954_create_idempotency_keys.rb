class CreateIdempotencyKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :idempotency_keys, id: :uuid do |t|
      t.string :key, null: false
      t.string :scope, null: false
      t.uuid :resource_id
      t.string :resource_type

      t.timestamps
    end

    # Add indexes
    add_index :idempotency_keys, [ :key, :scope ], unique: true
    add_index :idempotency_keys, [ :resource_type, :resource_id ]
  end
end
