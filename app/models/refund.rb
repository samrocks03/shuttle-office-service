# frozen_string_literal: true

class Refund < ApplicationRecord
  include UidGenerator

  belongs_to :payment, inverse_of: :refunds

  validates :gateway_refund_id, :status, presence: true
  validates :gateway_refund_id, uniqueness: true
  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }
end
