# frozen_string_literal: true

module Distances
  # Straight-line estimate with a road-winding factor; no duration available.
  class Haversine < Provider
    EARTH_RADIUS_KM = 6371.0
    ROAD_FACTOR = 1.4

    def matrix(sources:, destinations:)
      sources.map do |source|
        destinations.map { |destination| Cell.new(km_between(source, destination), nil) }
      end
    end

    private

    def km_between(from, to)
      lat1 = radians(from.latitude)
      lat2 = radians(to.latitude)
      d_lat = lat2 - lat1
      d_lng = radians(to.longitude) - radians(from.longitude)
      a = (Math.sin(d_lat / 2)**2) + (Math.cos(lat1) * Math.cos(lat2) * (Math.sin(d_lng / 2)**2))
      EARTH_RADIUS_KM * 2 * Math.asin(Math.sqrt(a)) * ROAD_FACTOR
    end

    def radians(degrees)
      degrees.to_f * Math::PI / 180
    end
  end
end
