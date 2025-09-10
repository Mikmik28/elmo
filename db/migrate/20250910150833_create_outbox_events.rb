class CreateOutboxEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :outbox_events, id: :uuid do |t|
      t.string :name, null: false
      t.uuid :aggregate_id, null: false
      t.string :aggregate_type, null: false
      t.jsonb :payload
      t.jsonb :headers
      t.boolean :processed, default: false, null: false
      t.integer :attempts, default: 0, null: false

      t.timestamps
    end

    # Add indexes
    add_index :outbox_events, :processed
    add_index :outbox_events, :name
    add_index :outbox_events, :created_at
    add_index :outbox_events, [ :processed, :created_at ]
    add_index :outbox_events, [ :aggregate_type, :aggregate_id ]
  end
end
