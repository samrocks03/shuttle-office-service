# frozen_string_literal: true

FactoryBot.define do
  factory :reservation do
    uid { SecureRandom.uuid }
    association :user
    association :schedule
  end
end
