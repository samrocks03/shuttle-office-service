# frozen_string_literal: true

module V1
  class StopSerializer
    include JSONAPI::Serializer

    attributes :uid, :name, :kind, :active, :osm_ref

    attribute(:latitude) { |stop| stop.latitude&.to_f }
    attribute(:longitude) { |stop| stop.longitude&.to_f }
    attribute(:city_uid) { |stop| stop.city.uid }
  end
end
