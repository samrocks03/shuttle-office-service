# frozen_string_literal: true

module Distances
  # Computes road distances between every active pickup and office of a city (both directions)
  # and upserts them into stop_distances. Manual overrides are never written.
  class ComputeForCity
    UPDATE_COLUMNS = %i[computed_km computed_minutes source computed_at].freeze

    def initialize(city, provider: nil)
      @city = city
      @provider = provider || Registry.fetch(city.distance_provider)
    end

    def call
      pickups = @city.stops.active.pickups.order(:id).to_a
      offices = @city.stops.active.offices.order(:id).to_a
      return { pairs: 0, unrouted: 0 } if pickups.empty? || offices.empty?

      now = Time.current
      rows = build_rows(pickups, offices, now) + build_rows(offices, pickups, now)
      StopDistance.upsert_all(
        rows,
        unique_by: %i[from_stop_id to_stop_id],
        update_only: UPDATE_COLUMNS,
        record_timestamps: true
      )

      { pairs: rows.size, unrouted: rows.count { |row| row[:computed_km].nil? } }
    end

    private

    def build_rows(sources, destinations, now)
      cells = @provider.matrix(sources: sources, destinations: destinations)
      sources.each_with_index.flat_map do |source, row|
        destinations.each_with_index.map do |destination, col|
          cell = cells[row][col]
          {
            from_stop_id: source.id,
            to_stop_id: destination.id,
            computed_km: cell.km,
            computed_minutes: cell.minutes,
            source: @city.distance_provider,
            computed_at: now,
            created_at: now,
            updated_at: now
          }
        end
      end
    end
  end
end
