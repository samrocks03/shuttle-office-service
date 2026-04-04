# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    uid { SecureRandom.uuid }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    phone_number { Faker::Number.unique.number(digits: 10).to_s }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    association :role, factory: [:role, :admin]
    association :company
  end
end
