# frozen_string_literal: true

class CreateBuses < ActiveRecord::Migration[7.0]
  def change
    create_table :buses do |t|
      t.text :number
      t.integer :capacity
      t.text :model
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end
  end
end
