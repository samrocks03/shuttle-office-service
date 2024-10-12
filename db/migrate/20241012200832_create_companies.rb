# frozen_string_literal: true

class CreateCompanies < ActiveRecord::Migration[7.0]
  def change
    create_table :companies do |t|
      t.text :name, null: false
      t.text :location, null: false
      t.timestamps
    end
  end
end
