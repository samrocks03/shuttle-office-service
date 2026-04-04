# frozen_string_literal: true

FactoryBot.define do
  factory :bus do
    uid { SecureRandom.uuid }
    number { Faker::Vehicle.unique.license_plate }
    capacity { Faker::Number.between(from: 20, to: 60) }
    model { Faker::Vehicle.make_and_model }
    association :company
  end
end
