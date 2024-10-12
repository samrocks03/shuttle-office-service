# frozen_string_literal: true

class CreateSchedules < ActiveRecord::Migration[7.0]
  def change
    create_table :schedules do |t|
      t.text :start_point
      t.references :bus, null: false, foreign_key: true
      t.date :date
      t.time :arrival_time
      t.time :departure_time
      t.integer :available_seats

      t.timestamps
    end
  end
end
