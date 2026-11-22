# frozen_string_literal: true

class Payment < ApplicationRecord
  include UidGenerator

  OPEN = %w[requires_payment_method requires_confirmation requires_customer_action processing].freeze

  belongs_to :reservation, inverse_of: :payments
  has_many :refunds, dependent: :restrict_with_exception, inverse_of: :payment

  validates :gateway, :gateway_payment_id, :status, :currency, presence: true
  validates :gateway_payment_id, uniqueness: true
  validates :amount_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def succeeded?
    status == 'succeeded'
  end
end
