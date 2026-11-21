# frozen_string_literal: true

# Ends a payment hold at hold_expires_at. Stub: the expiry logic arrives with Task 14.
class ReservationHoldExpiryJob < ApplicationJob
  queue_as :default

  def perform(reservation_id); end
end
