# frozen_string_literal: true

module V1
  class FareTableSerializer
    include JSONAPI::Serializer

    attributes :uid, :service_class, :currency, :policy, :effective_from, :active, :step_amount_minor

    attribute(:step_km) { |table| table.step_km&.to_f }
    attribute(:city_uid) { |table| table.city.uid }

    # Slabs come ordered by up_to_km (see FareTable#fare_slabs).
    attribute :slabs do |table|
      table.fare_slabs.map { |slab| { up_to_km: slab.up_to_km.to_f, amount_minor: slab.amount_minor } }
    end
  end
end
