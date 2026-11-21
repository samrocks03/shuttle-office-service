# frozen_string_literal: true

class CreateFareTables < ActiveRecord::Migration[7.0]
  def change
    create_table :fare_tables do |t|
      t.uuid :uid, null: false, default: -> { 'gen_random_uuid()' }
      t.references :city, null: false, foreign_key: true
      t.string :service_class, null: false
      t.string :currency, null: false
      t.string :policy, null: false, default: 'slab'
      t.date :effective_from, null: false
      t.boolean :active, null: false, default: true
      t.decimal :step_km, precision: 8, scale: 3
      t.integer :step_amount_minor

      t.timestamps
    end

    add_index :fare_tables, :uid, unique: true, name: 'index_fare_tables_on_uid'
    add_index :fare_tables, %i[city_id service_class effective_from], name: 'index_fare_tables_on_lookup'

    create_table :fare_slabs do |t|
      t.uuid :uid, null: false, default: -> { 'gen_random_uuid()' }
      t.references :fare_table, null: false, foreign_key: true
      t.decimal :up_to_km, precision: 8, scale: 3, null: false
      t.integer :amount_minor, null: false

      t.timestamps
    end

    add_index :fare_slabs, :uid, unique: true, name: 'index_fare_slabs_on_uid'
    add_index :fare_slabs, %i[fare_table_id up_to_km], unique: true
  end
end
