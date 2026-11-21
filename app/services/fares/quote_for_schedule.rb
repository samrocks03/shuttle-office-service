# frozen_string_literal: true

module Fares
  # Prices a schedule: bus service class + city + ride date -> fare table, and the stop pair ->
  # effective km -> policy -> Quote. Returns nil and sets #reason for the first missing piece,
  # checked in this order: :no_city, :no_stops, :no_distance, :no_fare_table.
  #
  # A misconfigured fare table (no slabs, no step, unknown policy) is not rescued here: the
  # error propagates so the bug is visible instead of showing as "no fare".
  class QuoteForSchedule
    attr_reader :reason

    def initialize(schedule)
      @schedule = schedule
    end

    def call
      @reason = nil

      city = @schedule.city
      return unavailable(:no_city) unless city
      return unavailable(:no_stops) unless @schedule.from_stop_id && @schedule.to_stop_id

      distance_km = @schedule.stop_distance&.effective_km
      return unavailable(:no_distance) unless distance_km

      fare_table = FareTable.active_on(city, @schedule.bus.service_class, @schedule.date)
      return unavailable(:no_fare_table) unless fare_table

      Registry.fetch(fare_table.policy).price(distance_km: distance_km, fare_table: fare_table)
    end

    private

    def unavailable(reason)
      @reason = reason
      nil
    end
  end
end
