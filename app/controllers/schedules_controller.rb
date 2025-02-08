# frozen_string_literal: true

class SchedulesController < ApplicationController
  # before_action :set_schedule, only: %i[show update destroy]

  load_and_authorize_resource
  # GET /schedules
  def index
    # from where is @schedules coming ???? ?

    # matches only those schedules that have a bus_id matching the bus_id
    # parameter passed in the request, if such parameter is present then
    # it will return all schedules for that particular bus.
    @schedules = Schedule.all
    # @schedules = Schedule.includes(:bus, :schedule).all

    if params[:order_by].present? && params[:order_type].present?
      @schedules = Schedule.all.order("#{params[:order_by]} #{params[:order_type]}")
    end
    @schedules = @schedules.where(bus_id: params[:bus_id]) if params[:bus_id].present?

    @pagy, @schedules = pagy(@schedules, page: params[:page], items: params[:per_page])
    # @schedules = Schedule.where('date >= ?', Date.today)
    # @schedules = Schedule.where('name ILIKE ?', params[:search_term]).all
    render json: {
      data_body: @schedules.map(&method(:schedule_json)),
      meta_data: {
        current_page_number: @pagy.items,
        current_page: @pagy.page,
        total_count: @pagy.count
      }
    }
    # render json: @schedules.map(&method(:schedule_json))
  end

  # GET /schedules/1
  def show
    # find() method is called when load_and_authorise is used while loading an Object.
    @schedule = params[:bus_id].present? && @schedule.bus_id == params[:bus_id].to_i ? @schedule : {}
    # if @schedule.present?
    render json: schedule_json(@schedule)
    # else
    # render json: { message: 'Schedule not found' }, status: :not_found
    # end
  end

  # POST /schedules
  def create
    @schedule = Schedule.new(schedule_params)
    if @schedule.date >= Date.today
      if @schedule.save
        render json: schedule_json(@schedule), status: :created, location: @schedule
      else
        render json: @schedule.errors.full_messages, status: :unprocessable_entity
      end
    else
      render json: { message: 'Cannot accept date before today!' }, status: :bad_request
    end
  end

  # PATCH/PUT
  def update
    if @schedule.update(schedule_params)
      render json: schedule_json(@schedule)
    else
      render json: @schedule.errors.full_messages, status: :unprocessable_entity
    end
  end

  def destroy
    @schedule.destroy
    render json: { message: 'Schedule was successfully destroyed' }
  end

  private

  # why after commenting this out, only a single schedule can be viewed in postman
  # Use callbacks to share common setup or constraints between actions.
  # def set_schedule
  #   @schedule = Schedule.find(params[:id])
  # end

  # Only allow a list of trusted parameters through.
  def schedule_params
    params.require(:schedule).permit(:start_point, :arrival_time, :date, :departure_time, :bus_id)
  end

  def schedule_json(schedule)
    return {} unless schedule.present?

    available_seats = schedule.bus.capacity - schedule.reservations.count
    {
      id: schedule.id,
      start_point: schedule.start_point,
      arrival_time: schedule.arrival_time.strftime('%H:%M'), # Format as HH:MM
      departure_time: schedule.departure_time.strftime('%H:%M'), # Format as HH:MM
      date: schedule.date,
      bus_id: schedule.bus_id,
      available_seats:,
      company_name: schedule.bus.company.name,
      company_id: schedule.bus.company_id
      # company_name: schedule.company.company_name
    }
  end
end
