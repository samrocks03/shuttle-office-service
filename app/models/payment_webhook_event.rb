# frozen_string_literal: true

class PaymentWebhookEvent < ApplicationRecord
  include UidGenerator

  validates :gateway, :event_id, :event_type, :received_at, presence: true
  validates :event_id, uniqueness: true
end
