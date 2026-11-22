# frozen_string_literal: true

class CreateStopDistances < ActiveRecord::Migration[7.0]
  def change
    create_table :stop_distances do |t|
      t.uuid :uid, null: false, default: -> { 'gen_random_uuid()' }
      t.references :from_stop, null: false, foreign_key: { to_table: :stops }
      t.references :to_stop, null: false, foreign_key: { to_table: :stops }
      t.decimal :computed_km, precision: 8, scale: 3
      t.integer :computed_minutes
      t.string :source
      t.datetime :computed_at
      t.decimal :override_km, precision: 8, scale: 3
      t.string :override_reason
      t.references :overridden_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :stop_distances, :uid, unique: true, name: 'index_stop_distances_on_uid'
    add_index :stop_distances, %i[from_stop_id to_stop_id], unique: true
    add_check_constraint :stop_distances, 'from_stop_id <> to_stop_id', name: 'stop_distances_distinct_stops'
  end
end
