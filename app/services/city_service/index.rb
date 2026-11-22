# frozen_string_literal: true

module CityService
  class Index < Base
    SUCCESS_KEY = 'city.index.success.message'
    MAX_ROWS = 500

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      cities = City.with_stops_count.order(:name).limit(MAX_ROWS)
      @data = V1::CitySerializer.new(cities).serializable_hash
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
