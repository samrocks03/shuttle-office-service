# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefundSyncJob do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:gateway) { FakeGateway.new }
  let(:payment) { create(:payment, gateway_payment_id: 'pay_refunded', status: 'succeeded') }

  before { Payments::Gateway.current = gateway }

  def refund(status: 'pending', gateway_refund_id: 'ref_1', age: 2.minutes, last_error: nil)
    payment.refunds.create!(amount_minor: 2000, reason: 'late_success', status: status, last_error: last_error,
                            gateway_refund_id: gateway_refund_id, created_at: age.ago)
  end

  it 'moves a pending refund to succeeded' do
    pending_refund = refund
    gateway.refund_status = 'succeeded'

    described_class.perform_now

    expect(gateway.calls[:fetch_refund]).to eq(['ref_1'])
    expect(pending_refund.reload.status).to eq('succeeded')
  end

  it 'leaves a refund the gateway still reports as pending' do
    pending_refund = refund

    described_class.perform_now

    expect(pending_refund.reload.status).to eq('pending')
  end

  it 'skips refunds younger than 1 minute, already final, or without a gateway id' do
    refund(gateway_refund_id: 'ref_young', age: 30.seconds)
    refund(gateway_refund_id: 'ref_done', status: 'succeeded')
    refund(gateway_refund_id: nil, status: 'failed', last_error: 'refund rejected by connector')

    described_class.perform_now

    expect(gateway.calls[:fetch_refund]).to be_empty
  end

  it 'keeps going when one refund cannot be fetched' do
    first = refund(gateway_refund_id: 'ref_a')
    second = refund(gateway_refund_id: 'ref_b')
    allow(gateway).to receive(:fetch_refund).and_call_original
    allow(gateway).to receive(:fetch_refund).with('ref_a')
                                            .and_return(Payments::Result.new(success: false, error: 'timeout'))
    gateway.refund_status = 'succeeded'

    described_class.perform_now

    expect(first.reload.status).to eq('pending')
    expect(second.reload.status).to eq('succeeded')
  end

  it 'queues its next run in 10 minutes' do
    freeze_time do
      expect { described_class.perform_now }.to have_enqueued_job(described_class).at(10.minutes.from_now)
    end
  end

  it 'still queues its next run when the gateway is not configured' do
    refund
    Payments::Gateway.current = nil
    allow(Payments::Gateway).to receive(:current).and_raise(Payments::NotConfigured, 'HYPERSWITCH_URL is not set')

    expect { described_class.perform_now }.to have_enqueued_job(described_class).exactly(:once)
  end
end
