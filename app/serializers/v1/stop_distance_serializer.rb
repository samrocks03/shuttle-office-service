# frozen_string_literal: true

module V1
  class StopDistanceSerializer
    include JSONAPI::Serializer

    attributes :uid, :computed_minutes, :source, :computed_at, :override_reason

    attribute(:computed_km) { |distance| distance.computed_km&.to_f }
    attribute(:override_km) { |distance| distance.override_km&.to_f }
    attribute(:effective_km) { |distance| distance.effective_km&.to_f }

    # A pair with no effective km cannot be priced, so bookings on it have no fare.
    attribute(:unrouted) { |distance| distance.effective_km.nil? }

    attribute(:from_stop) { |distance| stop_summary(distance.from_stop) }
    attribute(:to_stop) { |distance| stop_summary(distance.to_stop) }

    attribute :overridden_by_name do |distance|
      user = distance.overridden_by
      user && "#{user.first_name} #{user.last_name}"
    end

    def self.stop_summary(stop)
      { uid: stop.uid, name: stop.name, kind: stop.kind }
    end
  end
end
