# frozen_string_literal: true

FactoryBot.define do
  factory :city do
    uid { SecureRandom.uuid }
    sequence(:name) { |n| "City #{n}" }
    country_code { 'IN' }
    currency { 'INR' }
    time_zone { 'Asia/Kolkata' }
    distance_provider { 'osrm' }
    payments_enabled { false }
  end
end
