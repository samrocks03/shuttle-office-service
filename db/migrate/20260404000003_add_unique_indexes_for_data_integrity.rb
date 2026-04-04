# frozen_string_literal: true

class AddUniqueIndexesForDataIntegrity < ActiveRecord::Migration[7.0]
  def change
    add_index :users, :email, unique: true
    add_index :users, :phone_number, unique: true
    add_index :companies, :name, unique: true
    add_index :buses, :number, unique: true
    add_index :reservations, %i[schedule_id user_id], unique: true, name: 'index_reservations_on_schedule_and_user'
  end
end
