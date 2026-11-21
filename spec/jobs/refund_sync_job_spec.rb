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

  it 'keeps going when applying one refund raises' do
    first = refund(gateway_refund_id: 'ref_a')
    second = refund(gateway_refund_id: 'ref_b')
    allow(gateway).to receive(:fetch_refund).and_call_original
    allow(gateway).to receive(:fetch_refund).with('ref_a').and_raise(ActiveRecord::StatementInvalid, 'boom')
    gateway.refund_status = 'succeeded'

    expect { described_class.perform_now }.to have_enqueued_job(described_class).exactly(:once)

    expect(first.reload.status).to eq('pending')
    expect(second.reload.status).to eq('succeeded')
  end

  describe 'open payments on finished reservations' do
    let(:schedule) { create(:schedule, available_seats: 10) }
    let(:reservation) do
      create(:reservation, schedule: schedule, status: 'pending_payment', fare_amount_minor: 3500, currency: 'INR')
    end
    let!(:open_payment) do
      create(:payment, reservation: reservation, gateway_payment_id: 'pay_open', status: 'processing',
                       amount_minor: 3500)
    end

    before do
      # The rider cancelled while the payment was pending and the gateway refused the cancel.
      Reservations::Transition.call(reservation, to: :cancelled, reason: 'spec')
      open_payment.update!(last_error: 'cancel rejected by connector')
    end

    it 'refunds a late success once when the gateway later reports it succeeded with no webhook' do
      gateway.payment_status = 'succeeded'

      described_class.perform_now

      expect(gateway.calls[:fetch_payment]).to eq([{ id: 'pay_open', sync: true }])
      expect(open_payment.reload.status).to eq('succeeded')
      expect(open_payment.refunds.sole).to have_attributes(reason: 'late_success', amount_minor: 3500)
      expect(reservation.reload).to be_cancelled
    end

    it 'does not refund a second time when the sweep runs again' do
      gateway.payment_status = 'succeeded'

      described_class.perform_now
      described_class.perform_now

      expect(gateway.calls[:create_refund].size).to eq(1)
      expect(Refund.count).to eq(1)
    end

    it 'leaves a payment still open on the gateway open, with no refund' do
      gateway.payment_status = 'processing'

      described_class.perform_now

      expect(open_payment.reload.status).to eq('processing')
      expect(Refund.count).to eq(0)
    end

    it 'skips payments not changed in the last 48 hours' do
      open_payment.update_columns(updated_at: 49.hours.ago)
      gateway.payment_status = 'succeeded'

      described_class.perform_now

      expect(gateway.calls[:fetch_payment]).to be_empty
      expect(Refund.count).to eq(0)
    end

    it 'skips open payments of a reservation still pending_payment' do
      other = create(:reservation, schedule: schedule, status: 'pending_payment', fare_amount_minor: 3500,
                                   currency: 'INR')
      create(:payment, reservation: other, gateway_payment_id: 'pay_live', status: 'processing')

      described_class.perform_now

      expect(gateway.calls[:fetch_payment].pluck(:id)).to eq(['pay_open'])
    end

    it 'keeps going when one payment raises' do
      second = create(:reservation, schedule: schedule, status: 'expired', fare_amount_minor: 3500, currency: 'INR')
      create(:payment, reservation: second, gateway_payment_id: 'pay_second', status: 'processing')
      allow(gateway).to receive(:fetch_payment).and_call_original
      allow(gateway).to receive(:fetch_payment).with('pay_open', sync: true).and_raise(Timeout::Error)
      gateway.payment_status = 'succeeded'

      described_class.perform_now

      expect(Payment.find_by(gateway_payment_id: 'pay_second').refunds.sole.reason).to eq('late_success')
    end
  end
end
