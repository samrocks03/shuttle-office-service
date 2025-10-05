# frozen_string_literal: true

class CreateRoles < ActiveRecord::Migration[7.0]
  def change
    create_table :roles do |t|
      t.text :name, null: false
      t.integer :role_type, default: 0, null: false
      t.timestamps
    end

    add_index :roles, :role_type
  end
end
