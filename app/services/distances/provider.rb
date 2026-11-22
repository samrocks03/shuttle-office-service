# frozen_string_literal: true

module Distances
  # Contract for distance providers.
  # #matrix returns one row per source, one Cell per destination (km and minutes are nil when no route).
  class Provider
    def matrix(sources:, destinations:)
      raise NotImplementedError, "#{self.class} must implement #matrix"
    end
  end
end
