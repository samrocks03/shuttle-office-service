# frozen_string_literal: true

class ReservationMailer < ApplicationMailer
  def confirmation(reservation, pdf_bytes)
    @reservation = reservation
    @user        = reservation.user
    @schedule    = reservation.schedule
    @bus         = @schedule.bus
    @company     = @bus.company

    attachments["reservation_#{reservation.uid}.pdf"] = {
      mime_type: 'application/pdf',
      content: pdf_bytes
    }

    mail(
      to: @user.email,
      subject: "Your Shuttle Reservation \u2014 #{@schedule.start_point} to #{@company.name} :#{reservation.uid}"
    )
  end
end
