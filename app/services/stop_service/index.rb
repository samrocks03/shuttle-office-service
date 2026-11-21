# frozen_string_literal: true

module StopService
  class Index < Base
    include CityLookup

    SUCCESS_KEY = 'stop.index.success.message'
    MAX_ROWS = 500

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      return set_response unless find_city(@params[:city_uid])

      stops = @city.stops.includes(:city).order(:kind, :name).limit(MAX_ROWS)
      @data = V1::StopSerializer.new(stops).serializable_hash
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
