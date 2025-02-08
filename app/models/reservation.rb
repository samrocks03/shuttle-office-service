# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :user
  belongs_to :schedule
  # has_one :payment

  validates :schedule_id, :user_id, presence: true
  validates :schedule_id, uniqueness: { scope: :user_id, message: 'is already booked ' }
  after_create :generate_reservation_pdf

  def generate_reservation_pdf
    pdf = Prawn::Document.new
    pdf.text 'Reservation Details'
    pdf.move_down 20
    pdf.text "Reservation ID: #{id}"
    pdf.text "User: #{user.first_name} #{user.last_name}"
    pdf.text "Schedule ID: #{schedule_id}"
    pdf.text "Start Point: #{schedule.start_point}"
    pdf.text "Arrival Time: #{schedule.arrival_time.strftime('%H:%M')}"
    pdf.text "Departure Time: #{schedule.departure_time.strftime('%H:%M')}"
    pdf.text "Date: #{schedule.date.strftime('%Y-%m-%d')}"
    pdf.text "Company Name: #{schedule.bus.company.name}"

    pdf_file_path = Rails.root.join('public', 'reservations', "reservation_#{id}.pdf")

    FileUtils.mkdir_p(File.dirname(pdf_file_path))
    pdf.render_file(pdf_file_path)
  end
end
