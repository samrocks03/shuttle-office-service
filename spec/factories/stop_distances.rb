# frozen_string_literal: true

FactoryBot.define do
  factory :stop_distance do
    uid { SecureRandom.uuid }
    association :from_stop, factory: :stop
    association :to_stop, factory: %i[stop office]
    computed_km { 18.4 }
    computed_minutes { 40 }
    source { 'osrm' }
    computed_at { Time.current }
  end
end
