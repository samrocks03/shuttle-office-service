# frozen_string_literal: true

module V1
  class ReservationSerializer
    include JSONAPI::Serializer

    attributes :uid, :created_at, :updated_at

    attribute :user do |reservation|
      {
        uid: reservation.user&.uid,
        first_name: reservation.user&.first_name,
        last_name: reservation.user&.last_name
      }
    end

    attribute :schedule do |reservation|
      {
        uid: reservation.schedule&.uid,
        start_point: reservation.schedule&.start_point,
        arrival_time: reservation.schedule&.arrival_time&.strftime('%H:%M'),
        departure_time: reservation.schedule&.departure_time&.strftime('%H:%M'),
        date: reservation.schedule&.date,
        company_name: reservation.schedule&.bus&.company&.name
      }
    end
  end
end
