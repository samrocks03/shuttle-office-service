# frozen_string_literal: true

module Fares
  # Contract for fare policies.
  # #price returns a Fares::Quote for a distance on a given fare table.
  class Policy
    def price(distance_km:, fare_table:)
      raise NotImplementedError, "#{self.class} must implement #price"
    end
  end
end
