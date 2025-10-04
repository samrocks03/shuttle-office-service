# frozen_string_literal: true

class BusesController < ApplicationController
  include Paginatable
  include Searchable

  SEARCH_FIELDS = %w[buses.number buses.model companies.name companies.location].freeze

  self.paginatable_options = { default_per_page: 10, max_per_page: 50 }

  skip_before_action :authorized, only: %i[show index]
  before_action :set_bus, only: %i[show update destroy]

  load_and_authorize_resource

  # GET /buses
  def index
    buses = Bus.includes(:company).all
    buses = apply_search(buses, SEARCH_FIELDS, params[:search])
    paginated_buses = paginate(buses)

    render json: {
      data: ActiveModelSerializers::SerializableResource.new(
        paginated_buses,
        each_serializer: BusSerializer
      ).serializable_hash,
      meta: pagination_meta
    }
  end

  # GET /buses/1
  def show
    render json: BusSerializer.new(@bus)
  end

  # POST /buses
  def create
    @bus = Bus.new(bus_params)

    if @bus.save
      render json: BusSerializer.new(@bus), status: :created
    else
      render json: {
        error: {
          message: 'Bus creation failed',
          details: @bus.errors.full_messages
        }
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /buses/1
  def update
    if @bus.update(bus_params)
      render json: BusSerializer.new(@bus)
    else
      render json: {
        error: {
          message: 'Bus update failed',
          details: @bus.errors.full_messages
        }
      }, status: :unprocessable_entity
    end
  end

  def destroy
    destroyed_bus_data = BusSerializer.new(@bus).serializable_hash

    render json: {
      message: 'Bus successfully deleted',
      data: destroyed_bus_data
    }, status: :ok
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
end
