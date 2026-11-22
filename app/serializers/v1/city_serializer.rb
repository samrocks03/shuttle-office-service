# frozen_string_literal: true

module V1
  class CitySerializer
    include JSONAPI::Serializer

    attributes :uid, :name, :country_code, :currency, :time_zone, :distance_provider, :payments_enabled

    attribute :stops_count do |city|
      city.has_attribute?(:stops_count) ? city[:stops_count].to_i : city.stops.count
    end
  end
end
