# frozen_string_literal: true

class ReservationConfirmationJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(reservation_id)
    reservation = Reservation
      .includes(user: :company, schedule: { bus: :company })
      .find(reservation_id)

    return if reservation.user.email.blank?

    pdf_bytes = Pdf::ReservationGenerator.new(reservation).render
    ReservationMailer.confirmation(reservation, pdf_bytes).deliver_now
  end
end
