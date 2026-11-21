# frozen_string_literal: true

class Reservation < ApplicationRecord
  include UidGenerator

  HOLD_DURATION = 10.minutes
  ACTIVE_STATUSES = %w[pending_payment confirmed].freeze

  enum status: {
    confirmed: 'confirmed',
    pending_payment: 'pending_payment',
    cancelled: 'cancelled',
    expired: 'expired'
  }

  belongs_to :user, inverse_of: :reservations
  belongs_to :schedule, inverse_of: :reservations
  belongs_to :fare_table, optional: true
  has_many :payments, dependent: :restrict_with_exception, inverse_of: :reservation

  validates :schedule_id, :user_id, presence: true
  # Mirrors the partial unique index: only active reservations block a re-booking.
  validates :schedule_id, uniqueness: {
    scope: :user_id, message: 'is already booked', conditions: -> { where(status: ACTIVE_STATUSES) }
  }, if: -> { ACTIVE_STATUSES.include?(status) }

  def open_payments
    payments.where(status: Payment::OPEN)
  end

  def succeeded_payment
    payments.find_by(status: 'succeeded')
  end
end
