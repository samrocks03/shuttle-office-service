# frozen_string_literal: true

require 'bigdecimal'

module Fares
  # BEST-style slab pricing: the first slab with distance_km <= up_to_km wins.
  # Beyond the last slab, step_amount_minor is added for each started step_km.
  class SlabPolicy < Policy
    def price(distance_km:, fare_table:)
      distance = to_decimal(distance_km)
      raise ArgumentError, 'distance_km must be positive' unless distance.positive?

      slabs = fare_table.fare_slabs.sort_by(&:up_to_km)
      raise ArgumentError, "fare table #{fare_table.id.inspect} has no slabs" if slabs.empty?

      slab = slabs.find { |s| distance <= s.up_to_km }
      amount, label = slab ? slab_quote(slab) : beyond_quote(distance, slabs.last, fare_table)

      Quote.new(amount_minor: amount, currency: fare_table.currency, distance_km: distance,
                slab_label: label, fare_table_id: fare_table.id)
    end

    private

    def to_decimal(value)
      BigDecimal(value.to_s)
    end

    def slab_quote(slab)
      [slab.amount_minor, "up to #{format_km(slab.up_to_km)} km"]
    end

    def beyond_quote(distance, last_slab, fare_table)
      step_km = fare_table.step_km
      step_amount = fare_table.step_amount_minor
      raise ArgumentError, 'fare table has no step configured for distances beyond the last slab' if step_km.nil? || step_amount.nil?

      steps = ((distance - last_slab.up_to_km) / step_km).ceil
      upper_bound = last_slab.up_to_km + (steps * step_km)
      [last_slab.amount_minor + (steps * step_amount), "#{format_km(upper_bound)} km slab"]
    end

    def format_km(km)
      km = BigDecimal(km.to_s)
      km.frac.zero? ? km.to_i.to_s : km.to_s('F')
    end
  end
end
