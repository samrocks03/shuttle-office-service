# frozen_string_literal: true

FactoryBot.define do
  factory :stop do
    uid { SecureRandom.uuid }
    association :city
    sequence(:name) { |n| "Stop #{n}" }
    kind { 'pickup' }
    latitude { 18.5204 }
    longitude { 73.8567 }
    active { true }

    trait :office do
      kind { 'office' }
    end
  end
end
