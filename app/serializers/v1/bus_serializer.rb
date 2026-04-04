# frozen_string_literal: true

module V1
  class BusSerializer
    include JSONAPI::Serializer

    attributes :uid, :number, :capacity, :model, :created_at, :updated_at

    attribute :company_name do |bus|
      bus.company&.name
    end

    attribute :company_location do |bus|
      bus.company&.location
    end

    attribute :company_uid do |bus|
      bus.company&.uid
    end
  end
end
