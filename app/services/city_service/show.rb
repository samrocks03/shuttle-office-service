# frozen_string_literal: true

module CityService
  class Show < Base
    SUCCESS_KEY = 'city.show.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      city = City.with_stops_count.find_by(uid: @params[:id])
      unless city
        add_error('city.not_found')
        return set_response
      end

      @data = V1::CitySerializer.new(city).serializable_hash
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
