# frozen_string_literal: true

module V1
  class ReservationSerializer
    include JSONAPI::Serializer

    attributes :uid, :status, :hold_expires_at, :created_at, :updated_at

    # The fare snapshot taken when the seat was held; nil for a free booking.
    attribute :fare do |reservation|
      next unless reservation.fare_amount_minor

      breakdown = reservation.fare_breakdown || {}
      {
        amount_minor: reservation.fare_amount_minor,
        currency: reservation.currency,
        distance_km: breakdown['distance_km']&.to_f,
        slab_label: breakdown['slab_label']
      }
    end

    # The latest refund across the reservation's payments, or nil. A failed refund waits for an
    # admin retry, so riders and admins both need to see it.
    attribute :refund do |reservation|
      latest = reservation.payments.flat_map(&:refunds).max_by { |refund| [refund.created_at, refund.id] }
      latest && { status: latest.status, amount_minor: latest.amount_minor, reason: latest.reason }
    end

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
