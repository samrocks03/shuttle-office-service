# frozen_string_literal: true

# In-memory stand-in for Payments::Hyperswitch. Records every call in #calls and returns
# Payments::Result values like the real gateway. Set fail_create / fail_cancel / fail_refund to
# make that call return a failed result.
class FakeGateway
  attr_reader :calls
  attr_accessor :fail_create, :fail_cancel, :fail_refund, :refund_status

  def initialize
    @calls = Hash.new { |hash, key| hash[key] = [] }
    @sequence = 0
    @refund_status = 'pending'
  end

  def create_payment(**args)
    calls[:create_payment] << args
    return failure('connector timed out (raw gateway text)') if fail_create

    id = next_id('pay')
    success(id: id, client_secret: "#{id}_secret_fake", status: 'requires_payment_method')
  end

  def fetch_payment(id, sync: false)
    calls[:fetch_payment] << { id: id, sync: sync }
    success(id: id, status: 'requires_payment_method', connector: nil, error: nil)
  end

  def cancel_payment(id)
    calls[:cancel_payment] << id
    return failure('cancel rejected by connector') if fail_cancel

    success(id: id, status: 'cancelled')
  end

  def create_refund(payment_id:, amount_minor:, reason:)
    calls[:create_refund] << { payment_id: payment_id, amount_minor: amount_minor, reason: reason }
    return failure('refund rejected by connector') if fail_refund

    success(id: next_id('ref'), status: refund_status)
  end

  def fetch_refund(id)
    calls[:fetch_refund] << id
    success(id: id, status: refund_status)
  end

  def verify_webhook(raw_body:, headers:)
    calls[:verify_webhook] << { raw_body: raw_body, headers: headers }
    true
  end

  private

  def next_id(prefix)
    @sequence += 1
    "#{prefix}_fake_#{@sequence}"
  end

  def success(data)
    Payments::Result.new(success: true, data: data)
  end

  def failure(error)
    Payments::Result.new(success: false, error: error)
  end
end

RSpec.configure do |config|
  config.after { Payments::Gateway.current = nil }
end
