# frozen_string_literal: true

module StopDistanceService
  class Index < Base
    include CityLookup

    SUCCESS_KEY = 'stop_distance.index.success.message'
    # A city has 2 x pickups x offices pairs (144 for Pune); this keeps one response bounded.
    MAX_ROWS = 500

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      return set_response unless find_city(@params[:city_uid])

      scope = StopDistance.joins(:from_stop).where(stops: { city_id: @city.id })
      distances = scope.preload(:from_stop, :to_stop, :overridden_by)
                       .order('stops.name', 'stop_distances.to_stop_id').limit(MAX_ROWS)
      @data = V1::StopDistanceSerializer.new(distances).serializable_hash
      @data[:meta] = { total_count: scope.count, max_rows: MAX_ROWS }
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
