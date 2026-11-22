# frozen_string_literal: true

module StopService
  class Destroy < Base
    include CityLookup

    SUCCESS_KEY = 'stop.destroy.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_city(@params[:city_uid]) && find_stop && destroy_stop && set_data && set_response) || set_response
    end

    private

    def find_stop
      @stop = @city.stops.find_by(uid: @params[:id])
      return true if @stop

      add_error('stop.not_found')
    end

    # Removes the stop's computed distances with it. A stop a schedule still uses is refused by the
    # foreign key, which rolls the whole delete back.
    def destroy_stop
      ActiveRecord::Base.transaction do
        StopDistance.where(from_stop_id: @stop.id).or(StopDistance.where(to_stop_id: @stop.id)).delete_all
        @stop.destroy!
      end
      true
    rescue ActiveRecord::InvalidForeignKey
      add_error('stop.destroy.failure')
    end

    def set_data
      @message = translate(SUCCESS_KEY)
    end
  end
end
