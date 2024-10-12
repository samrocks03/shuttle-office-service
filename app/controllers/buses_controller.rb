# frozen_string_literal: true

class BusesController < ApplicationController
  before_action :set_bus, only: %i[show update destroy]

  load_and_authorize_resource
  # GET /buses
  def index
    @buses = Bus.all
    # render json: @buses.map(&method(:as_json)), status: :created, location: @bus
    # render json: @buses.map(&method(:as_json))
    # render json: @buses.as_json

    # Searching based on params
    if params[:search].present?
      @buses = @buses.joins(:company).where("
      buses.number ILIKE ? OR
      buses.model ILIKE ? OR
      companies.name ILIKE ?",
                                            "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%")

    end

    # Sorting based on asc/ desc if given
    if params[:order_by].present? && params[:order_type].present?
      order_clause = "#{params[:order_by]} #{params[:order_type]}"
      @buses = @buses.order(order_clause)
    end

    # Pagination with per_page
    if params[:per_page].present? && params[:page].present?
      @pagy, @buses = pagy(@buses, page: params[:page], items: params[:per_page])
    end

    # render json: @buses.map(&method(:buses_json))
    render json: {
      data_body: @buses.map(&method(:buses_json)),
      meta_data: {
        current_page_number: @pagy&.items || @buses.count,
        current_page: @pagy&.page || 1,
        total_count: @pagy&.count || @buses.count
      }
    }, status: :ok
    # render json: @buses.map(&method(:bus_json))
    # @buses = Bus.all
  end

  # GET /buses/1
  def show
    # render json: @bus
    render json: @bus.as_json
    # render json: bus_json(@bus)
  end

  # POST /buses
  def create
    @bus = Bus.new(bus_params)

    if @bus.save
      render json: @bus.as_json, status: :created, location: @bus
      # render json: bus_json(@bus), status: :created, location: @bus
    else
      render json: @bus.errors.full_messages, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /buses/1
  # PATCH/PUT
  def update
    if @bus.update(bus_params)
      render json: @bus.as_json, status: :ok
    else
      render json: @bus.errors.full_messages, status: :unprocessable_entity
    end
  end

  def destroy
    @bus.destroy
    render json: { message: 'Bus was successfully destroyed' }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_bus
    @bus = Bus.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def bus_params
    params.require(:bus).permit(:number, :capacity, :model, :company_id)
  end

  # Custom method to render bus JSON
  def buses_json(bus)
    {
      id: bus.id,
      number: bus.number,
      capacity: bus.capacity,
      model: bus.model,
      company: bus.company.name
    }
  end
end
