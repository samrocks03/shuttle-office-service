# frozen_string_literal: true

class CreateStops < ActiveRecord::Migration[7.0]
  def change
    create_table :stops do |t|
      t.uuid :uid, null: false, default: -> { 'gen_random_uuid()' }
      t.references :city, null: false, foreign_key: true
      t.references :company, null: true, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.string :osm_ref
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :stops, :uid, unique: true, name: 'index_stops_on_uid'
    add_index :stops, %i[city_id kind active]
  end
end
