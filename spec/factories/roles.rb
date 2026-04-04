# frozen_string_literal: true

FactoryBot.define do
  factory :role do
    uid { SecureRandom.uuid }
    name { Faker::Job.unique.title }
    role_type { :admin }

    trait :admin do
      name { 'Admin' }
      role_type { :admin }
    end

    trait :user_role do
      name { 'User' }
      role_type { :user }
    end

    trait :guest do
      name { 'Guest' }
      role_type { :guest }
    end
  end
end
