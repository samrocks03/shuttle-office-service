# frozen_string_literal: true

module Distances
  class Registry
    PROVIDERS = { 'osrm' => Osrm, 'haversine' => Haversine }.freeze

    def self.fetch(name)
      PROVIDERS.fetch(name.to_s) { raise UnknownProvider, "Unknown distance provider: #{name.inspect}" }.new
    end
  end
end
