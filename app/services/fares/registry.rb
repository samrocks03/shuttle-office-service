# frozen_string_literal: true

module Fares
  class Registry
    POLICIES = { 'slab' => SlabPolicy }.freeze

    def self.fetch(name)
      POLICIES.fetch(name.to_s) { raise UnknownPolicy, "Unknown fare policy: #{name.inspect}" }.new
    end
  end
end
