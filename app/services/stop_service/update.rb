# frozen_string_literal: true

module StopService
  class Update < Base
    include CityLookup

    SUCCESS_KEY = 'stop.update.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_city(@params[:city_uid]) && find_stop && update_stop && set_data && set_response) || set_response
    end

    private

    def find_stop
      @stop = @city.stops.find_by(uid: @params[:id])
      return true if @stop

      add_error('stop.not_found')
    end

    def update_stop
      return true if @stop.update(@params.slice(*Create::ATTRIBUTES))

      add_error('stop.update.failure', message: @stop.errors.full_messages.join(', '))
    end

    def set_data
      @data = V1::StopSerializer.new(@stop).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
