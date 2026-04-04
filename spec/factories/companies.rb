# frozen_string_literal: true

FactoryBot.define do
  factory :company do
    uid { SecureRandom.uuid }
    name { Faker::Company.unique.name }
    location { Faker::Address.city }
  end
end
