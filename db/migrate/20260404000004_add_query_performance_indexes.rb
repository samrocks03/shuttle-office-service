# frozen_string_literal: true

class AddQueryPerformanceIndexes < ActiveRecord::Migration[7.0]
  def change
    add_index :schedules, :date, name: 'index_schedules_on_date'
    add_index :schedules, %i[bus_id date], name: 'index_schedules_on_bus_id_and_date'
  end
end
