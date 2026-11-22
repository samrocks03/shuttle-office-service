# frozen_string_literal: true

module StopService
  class Show < Base
    include CityLookup

    SUCCESS_KEY = 'stop.show.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      return set_response unless find_city(@params[:city_uid])

      stop = @city.stops.find_by(uid: @params[:id])
      unless stop
        add_error('stop.not_found')
        return set_response
      end

      @data = V1::StopSerializer.new(stop).serializable_hash
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
