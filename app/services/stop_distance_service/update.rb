# frozen_string_literal: true

module StopDistanceService
  # Sets or clears the manual override on one pair. Admin only (enforced by the controller).
  # `override_km: nil` clears the override, its reason and who made it; the computed values are
  # never touched, and Distances::ComputeForCity never writes the override columns.
  class Update < Base
    SUCCESS_KEY = 'stop_distance.update.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_distance && parse_override && save_override && set_data && set_response) || set_response
    end

    private

    def find_distance
      @distance = StopDistance.find_by(uid: @params[:id])
      return true if @distance

      add_error('stop_distance.not_found')
    end

    def parse_override
      return add_error('stop_distance.override_km_required') unless @params.key?(:override_km)

      raw = @params[:override_km]
      @clear = raw.nil?
      return true if @clear

      @override_km = Float(raw, exception: false)
      return true if @override_km&.finite?

      add_error('stop_distance.override_km_invalid')
    end

    def save_override
      if @clear
        @distance.assign_attributes(override_km: nil, override_reason: nil, overridden_by_id: nil)
      else
        @distance.assign_attributes(override_km: @override_km, override_reason: @params[:override_reason].presence&.strip,
                                    overridden_by_id: @current_user[:user_id])
      end
      return true if @distance.save

      add_error('stop_distance.update.failure', message: @distance.errors.full_messages.join(', '))
    end

    def set_data
      @data = V1::StopDistanceSerializer.new(@distance.reload).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
