# frozen_string_literal: true

module V1
  class ScheduleSerializer
    include JSONAPI::Serializer

    attributes :uid, :start_point, :date, :available_seats, :created_at, :updated_at

    # Every serialization gets its own memo so `fare` and `fare_unavailable_reason` share one quote
    # lookup per schedule.
    def initialize(resource, options = {})
      params = (options[:params] || {}).merge(fare_quotes: {}.compare_by_identity)
      super(resource, options.merge(params: params))
    end

    def self.quote_for(schedule, params)
      params[:fare_quotes][schedule] ||= begin
        service = Fares::QuoteForSchedule.new(schedule)
        [service.call, service.reason]
      end
    end

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

    attribute :bus_service_class do |schedule|
      schedule.bus&.service_class
    end

    # Whether a booking on this schedule is paid (the bus's company's city has payments on). The
    # frontend shows fare UI only when true, so companies without paid rides see no change.
    attribute :payments_enabled do |schedule|
      schedule.city&.payments_enabled || false
    end

    attribute :fare do |schedule, params|
      quote, = quote_for(schedule, params)
      quote && {
        amount_minor: quote.amount_minor,
        currency: quote.currency,
        distance_km: quote.distance_km.to_f.round(3),
        slab_label: quote.slab_label
      }
    end

    attribute :fare_unavailable_reason do |schedule, params|
      _, reason = quote_for(schedule, params)
      reason&.to_s
    end

    attribute :booked_by_current_user do |schedule, params|
      params[:booked_schedule_ids]&.include?(schedule.id) || false
    end
  end
end
