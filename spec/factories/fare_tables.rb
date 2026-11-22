# frozen_string_literal: true

FactoryBot.define do
  factory :fare_table do
    uid { SecureRandom.uuid }
    city
    service_class { 'non_ac' }
    currency { 'INR' }
    policy { 'slab' }
    effective_from { Date.new(2026, 1, 1) }
    active { true }
    step_km { 5 }
    step_amount_minor { 500 }

    # Pune, from Mumbai BEST slabs, in paise: [up to km, amount_minor]
    trait :best_non_ac do
      service_class { 'non_ac' }

      after(:create) do |table|
        [[5, 1000], [10, 1500], [15, 2000], [20, 3000], [25, 3500],
         [30, 4000], [35, 4500], [40, 5000], [45, 5500], [50, 6000]].each do |up_to_km, amount_minor|
          create(:fare_slab, fare_table: table, up_to_km: up_to_km, amount_minor: amount_minor)
        end
      end
    end

    trait :best_ac do
      service_class { 'ac' }

      after(:create) do |table|
        [[5, 1200], [10, 2000], [15, 3000], [20, 3500], [25, 4000],
         [30, 4500], [35, 5000], [40, 5500], [45, 6000], [50, 6500]].each do |up_to_km, amount_minor|
          create(:fare_slab, fare_table: table, up_to_km: up_to_km, amount_minor: amount_minor)
        end
      end
    end
  end

  factory :fare_slab do
    uid { SecureRandom.uuid }
    fare_table
    up_to_km { 5 }
    amount_minor { 1000 }
  end
end
