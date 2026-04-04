# frozen_string_literal: true

FactoryBot.define do
  factory :schedule do
    uid { SecureRandom.uuid }
    start_point { Faker::Address.street_name }
    sequence(:departure_time) { |n| "#{(8 + (n * 2) % 12).to_s.rjust(2, '0')}:00" }
    sequence(:arrival_time) { |n| "#{(9 + (n * 2) % 12).to_s.rjust(2, '0')}:00" }
    sequence(:date) { |n| Date.tomorrow + n.days }
    available_seats { 40 }
    association :bus

    trait :past do
      date { Date.yesterday }
    end
  end
end
