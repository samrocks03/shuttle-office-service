# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    uid { SecureRandom.uuid }
    reservation
    gateway { 'hyperswitch' }
    sequence(:gateway_payment_id) { |n| "pay_test_#{n}" }
    status { 'requires_payment_method' }
    amount_minor { 2000 }
    currency { 'INR' }
  end
end
