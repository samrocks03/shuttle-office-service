# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone_number, null: false
      t.string :password_digest, null: false
      t.text :email, null: false
      t.references :company, null: false, foreign_key: true
      t.references :role, foreign_key: true, default: 1

      t.timestamps
    end
  end
end
