# frozen_string_literal: true

class BusSerializer < ActiveModel::Serializer
  attributes :id, :number, :capacity, :model, :company_id

  attribute :company_name do
    object.company&.name
  end

  attribute :company_location do
    object.company&.location
  end

  attribute :schedules_count, if: -> { instance_options[:include_schedules_count] } do
    object.schedules.count
  end
end
