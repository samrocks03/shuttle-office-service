# frozen_string_literal: true

class AddRoutingColumns < ActiveRecord::Migration[7.0]
  def change
    add_reference :companies, :city, null: true, foreign_key: true
    add_column :buses, :service_class, :string, null: false, default: 'non_ac'
    add_reference :schedules, :from_stop, null: true, foreign_key: { to_table: :stops }
    add_reference :schedules, :to_stop, null: true, foreign_key: { to_table: :stops }
  end
end
