# frozen_string_literal: true

module V1
  class ScheduleSerializer
    include JSONAPI::Serializer

    attributes :uid, :start_point, :date, :available_seats, :created_at, :updated_at

    attribute :arrival_time do |schedule|
      schedule.arrival_time&.strftime('%H:%M')
    end

    attribute :departure_time do |schedule|
      schedule.departure_time&.strftime('%H:%M')
    end

    attribute :bus_uid do |schedule|
      schedule.bus&.uid
    end

    attribute :company_name do |schedule|
      schedule.bus&.company&.name
    end

    attribute :company_uid do |schedule|
      schedule.bus&.company&.uid
    end

    attribute :bus_number do |schedule|
      schedule.bus&.number
    end

    attribute :bus_capacity do |schedule|
      schedule.bus&.capacity
    end
  end
end
