# frozen_string_literal: true

class Refund < ApplicationRecord
  include UidGenerator

  belongs_to :payment, inverse_of: :refunds

  validates :status, presence: true
  # A refund the gateway refused has no gateway id; every other refund must have one.
  validates :gateway_refund_id, presence: true, unless: -> { status == 'failed' }
  validates :gateway_refund_id, uniqueness: true, allow_nil: true
  validates :amount_minor, numericality: { only_integer: true, greater_than: 0 }
end
