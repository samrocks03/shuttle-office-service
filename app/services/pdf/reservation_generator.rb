# frozen_string_literal: true

module Pdf
  class ReservationGenerator < BaseGenerator
    def initialize(reservation)
      super()
      @reservation = reservation
      @schedule    = reservation.schedule
      @bus         = @schedule.bus
      @company     = @bus.company
      @user        = reservation.user
    end

    private

    def build_content
      header('Reservation Confirmation', "##{@reservation.uid}")
      route_section
      passenger_section
      booking_section
      qr_placeholder
      boarding_notice
    end

    def route_section
      section('Route') do
        render_times
        render_route_names
        info_row 'Date', @schedule.date.strftime('%A, %B %d, %Y')
        info_row 'Bus', "#{@bus.number} — #{@bus.model}"
        info_row 'Company', @company.name
      end
    end

    def render_times
      y = @document.cursor
      @document.font_size(28) do
        @document.fill_color TEXT_COLOR
        @document.text_box format_time(@schedule.departure_time),
          at: [0, y], width: 100, style: :bold
        @document.fill_color MUTED_COLOR
        @document.text_box ">>",
          at: [110, y], width: 30, align: :center
        @document.fill_color TEXT_COLOR
        @document.text_box format_time(@schedule.arrival_time),
          at: [150, y], width: 100, style: :bold
      end
      @document.move_down 36
    end

    def render_route_names
      y = @document.cursor
      @document.font_size(11) do
        @document.fill_color TEXT_COLOR
        @document.text_box @schedule.start_point,
          at: [0, y], width: 200
        @document.fill_color MUTED_COLOR
        @document.text_box ">>",
          at: [200, y], width: 20, align: :center
        @document.fill_color TEXT_COLOR
        @document.text_box @company.name,
          at: [220, y], width: 200
      end
      @document.move_down 22
      reset_colors
    end

    def passenger_section
      section('Passenger') do
        info_row 'Name', "#{@user.first_name} #{@user.last_name}"
        info_row 'Email', @user.email
        info_row 'Company', @user.company&.name
      end
    end

    def booking_section
      section('Booking Details') do
        info_row 'Reservation ID', @reservation.uid
        info_row 'Seats Available', "#{@schedule.available_seats} / #{@bus.capacity}"
        info_row 'Booked At', @reservation.created_at.strftime('%B %d, %Y at %H:%M')
      end
    end

    def qr_placeholder
      y = @document.cursor
      @document.stroke_color BORDER_COLOR
      @document.dash(2)
      @document.stroke_rectangle [@document.bounds.width - 84, y], 80, 80
      @document.undash
      @document.fill_color MUTED_COLOR
      @document.font_size(7) do
        @document.text_box 'QR CODE',
          at: [@document.bounds.width - 84, y - 30],
          width: 80, align: :center, style: :bold
        @document.text_box '(coming soon)',
          at: [@document.bounds.width - 84, y - 42],
          width: 80, align: :center
      end
      reset_colors
      @document.move_down 20
    end

    def boarding_notice
      @document.move_down 10
      notice_y = @document.cursor
      @document.fill_color BRAND_COLOR
      @document.fill_rounded_rectangle [0, notice_y], @document.bounds.width, 36, 4
      @document.fill_color WHITE
      @document.font_size(10) do
        @document.text_box 'This is your boarding pass. Please present it to the driver.',
          at: [12, notice_y - 10],
          width: @document.bounds.width - 24,
          height: 16,
          style: :bold
      end
      reset_colors
    end

    def format_time(time)
      time.strftime('%H:%M')
    end
  end
end
