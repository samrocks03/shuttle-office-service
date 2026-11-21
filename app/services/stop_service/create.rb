# frozen_string_literal: true

module StopService
  class Create < Base
    include CityLookup

    SUCCESS_KEY = 'stop.create.success.message'
    ATTRIBUTES = %i[name kind latitude longitude active osm_ref].freeze

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_city(@params[:city_uid]) && create_stop && set_data && set_response) || set_response
    end

    private

    def create_stop
      @stop = @city.stops.build(@params.slice(*ATTRIBUTES))
      return true if @stop.save

      add_error('stop.create.failure', message: @stop.errors.full_messages.join(', '))
    end

    def set_data
      @data = V1::StopSerializer.new(@stop).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
