# frozen_string_literal: true

class ReservationConfirmationJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(reservation_id)
    reservation = Reservation
                  .includes(user: :company, schedule: { bus: :company })
                  .find(reservation_id)

    unless reservation.confirmed?
      logger.info "[ReservationConfirmation] Skipping reservation #{reservation.uid} — status is #{reservation.status}"
      return
    end

    if reservation.user.email.blank?
      logger.info "[ReservationConfirmation] Skipping reservation #{reservation.uid} — user has no email"
      return
    end

    route = "#{reservation.schedule.start_point} -> #{reservation.schedule.bus.company.name}"
    logger.info "[ReservationConfirmation] Generating PDF for #{reservation.uid} (#{route})"

    pdf_bytes = Pdf::ReservationGenerator.new(reservation).render

    logger.info "[ReservationConfirmation] Sending to #{reservation.user.email} for reservation #{reservation.uid}"
    ReservationMailer.confirmation(reservation, pdf_bytes).deliver_now
    logger.info "[ReservationConfirmation] Delivered to #{reservation.user.email} for reservation #{reservation.uid}"
  end
end
