# frozen_string_literal: true

class CreateCities < ActiveRecord::Migration[7.0]
  def change
    create_table :cities do |t|
      t.uuid :uid, null: false, default: -> { 'gen_random_uuid()' }
      t.string :name, null: false
      t.string :country_code, null: false
      t.string :currency, null: false
      t.string :time_zone, null: false
      t.string :distance_provider, null: false, default: 'osrm'
      t.boolean :payments_enabled, null: false, default: false

      t.timestamps
    end

    add_index :cities, :uid, unique: true, name: 'index_cities_on_uid'
  end
end
