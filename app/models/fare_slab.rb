# frozen_string_literal: true

class FareSlab < ApplicationRecord
  include UidGenerator

  belongs_to :fare_table, inverse_of: :fare_slabs

  validates :up_to_km, numericality: { greater_than: 0 }
  validates :amount_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :up_to_km, uniqueness: { scope: :fare_table_id }
end
