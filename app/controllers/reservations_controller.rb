# frozen_string_literal: true

class ReservationsController < ApplicationController
  before_action :set_reservation, only: %i[show update destroy]

  load_and_authorize_resource
  # GET /reservations
  def index
    # @reservations = Reservation.includes(user: {schedule: {bus: :company} }).all
    # @reservations = Reservation.includes(users: { schedules: [:bus, :company] }).all
    # @reservations = Reservation.includes(user: { schedule: [:bus, :company] }).all
    #
    #
    # @reservations = Reservation.all
    @reservations = Reservation.includes(:user, schedule: { bus: :company }).all
    # @reservations = Reservation.includes(user: { company: :buses }, schedule: :bus).all

    # @reservations = Reservation.all
    # server side searching for reservations controller
    if params[:search].present?
      # @reservations = @reservations.includes(user: { company: :buses }, schedule: :bus)
      search_term = "%#{params[:search]}%"
      # debugger
      @reservations = @reservations
                      .joins(:user, schedule: { bus: :company })
                      .where(" (
        CAST(reservations.id AS TEXT) ILIKE ? OR
        users.first_name ILIKE ? OR
        users.last_name ILIKE ? OR
        schedules.start_point ILIKE ? OR
        TO_CHAR(schedules.arrival_time, 'HH24:MI') ILIKE ? OR
        TO_CHAR(schedules.departure_time, 'HH24:MI') ILIKE ? OR
        TO_CHAR(schedules.date, 'YYYY-MM-DD') ILIKE ? OR
        CAST(schedules.id AS TEXT) ILIKE ? OR
        companies.name ILIKE ?
        ) ", search_term, search_term, search_term, search_term,
                             search_term, search_term, search_term, search_term, search_term)

    end

    # Sorting based on asc/ desc if given
    if params[:order_by].present? && params[:order_type].present?
      order_clause = "#{params[:order_by]} #{params[:order_type]}"
      @reservations = @reservations.order(order_clause)
    end

    if params[:per_page].present? && params[:page].present?
      @pagy, @reservations = pagy(@reservations, page: params[:page], items: params[:per_page])
    end

    render json: {
      data_body: @reservations.map(&method(:reservation_json)),
      meta_data: {
        current_page_number: @pagy&.items || 1,
        current_page: @pagy&.page || 1,
        total_count: @pagy&.count || @reservations.count
      }
    }, status: :ok

    # render json: @reservations.map(&method(:reservation_json))
  end

  # GET /reservations/1
  def show
    render json: reservation_json(@reservation)
  end

  # POST /reservations
  def create
    @reservation = Reservation.new(reservation_params)
    @schedule = @reservation.schedule

    # Check if there are available seats on the bus
    if @schedule.available_seats.positive?
      if @reservation.save
        # Update the available seats count
        @schedule.decrement_available_seat
        # @reservation.generate_reservation_pdf
        render json: reservation_json(@reservation), status: :created, location: @reservation
      else
        render json: @reservation.errors.full_messages, status: :unprocessable_entity
      end
    else
      render json: { message: 'Cannot make reservation, no seats available!' }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /reservations/1
  # PATCH/PUT
  def update
    if @reservation.update(reservation_params)
      render json: reservation_json(@reservation)
    else
      render json: @reservation.errors.full_messages, status: :unprocessable_entity
    end
  end

  def destroy
    @reservation.destroy
    render json: { message: 'Reservation was successfully destroyed' }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_reservation
    @reservation = Reservation.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def reservation_params
    params.require(:reservation).permit(:user_id, :schedule_id)
  end

  def reservation_json(reservation)
    {
      id: reservation.id,
      first_name: reservation.user.first_name,
      last_name: reservation.user.last_name,
      user_id: reservation.user_id,
      schedule_id: reservation.schedule_id,
      schedule: {
        id: reservation.schedule.id,
        start_point: reservation.schedule.start_point,
        arrival_time: reservation.schedule.arrival_time.strftime('%H:%M'),
        departure_time: reservation.schedule.departure_time.strftime('%H:%M'),
        date: reservation.schedule.date,
        company_name: reservation.schedule.bus.company.name
        # bus: {
        #  id: reservation.schedule.bus.id,
        #  number: reservation.schedule.bus.number,
        #  capacity: reservation.schedule.bus.capacity,
        #  model: reservation.schedule.bus.model
        # }
      }
    }
  end
end
