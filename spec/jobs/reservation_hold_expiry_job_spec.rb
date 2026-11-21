# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationHoldExpiryJob do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:gateway) { FakeGateway.new }
  let(:schedule) { create(:schedule, available_seats: 10) }
  let(:reservation) { create(:reservation, schedule: schedule, status: reservation_status) }
  let(:reservation_status) { 'pending_payment' }
  let!(:payment) do
    create(:payment, reservation: reservation, gateway_payment_id: 'pay_hold', status: 'requires_payment_method')
  end

  before { Payments::Gateway.current = gateway }

  def run(attempt = 0)
    described_class.perform_now(reservation.id, attempt)
  end

  context 'when the payment succeeded by expiry time' do
    before { gateway.payment_status = 'succeeded' }

    it 'confirms the reservation and keeps the seat taken' do
      run

      expect(gateway.calls[:fetch_payment]).to eq([{ id: 'pay_hold', sync: true }])
      expect(payment.reload.status).to eq('succeeded')
      expect(reservation.reload.status).to eq('confirmed')
      expect(schedule.reload.available_seats).to eq(10)
      expect(gateway.calls[:cancel_payment]).to be_empty
    end

    it 'does not queue itself again' do
      expect { run }.not_to have_enqueued_job(described_class)
    end
  end

  %w[processing requires_customer_action].each do |status|
    context "when the gateway still reports the payment as #{status}" do
      before { gateway.payment_status = status }

      it 'keeps the hold and queues itself again in 2 minutes with the next attempt' do
        freeze_time do
          expect { run(2) }.to have_enqueued_job(described_class)
            .with(reservation.id, 3).at(2.minutes.from_now)
        end

        expect(reservation.reload.status).to eq('pending_payment')
        expect(schedule.reload.available_seats).to eq(10)
        expect(payment.reload.status).to eq(status)
        expect(gateway.calls[:cancel_payment]).to be_empty
      end
    end
  end

  context 'when the payment is still processing after 5 re-enqueues' do
    before { gateway.payment_status = 'processing' }

    it 'expires the hold, releases the seat and tries to cancel the payment' do
      expect { run(5) }.not_to have_enqueued_job(described_class)

      expect(reservation.reload.status).to eq('expired')
      expect(schedule.reload.available_seats).to eq(11)
      expect(gateway.calls[:cancel_payment]).to eq(['pay_hold'])
    end
  end

  context 'when the payment failed' do
    before { gateway.payment_status = 'failed' }

    it 'expires the reservation and gives the seat back' do
      run

      expect(payment.reload.status).to eq('failed')
      expect(reservation.reload.status).to eq('expired')
      expect(schedule.reload.available_seats).to eq(11)
    end
  end

  context 'when the payment is still waiting for a payment method' do
    it 'cancels the payment through the gateway, applies the cancel and expires the reservation' do
      expect { run }.not_to have_enqueued_job(described_class)

      expect(gateway.calls[:cancel_payment]).to eq(['pay_hold'])
      expect(payment.reload.status).to eq('cancelled')
      expect(reservation.reload.status).to eq('expired')
      expect(schedule.reload.available_seats).to eq(11)
    end

    it 'records the error but still expires when the gateway refuses the cancel' do
      gateway.fail_cancel = true

      run

      expect(payment.reload).to have_attributes(status: 'requires_payment_method',
                                                last_error: 'cancel rejected by connector')
      expect(reservation.reload.status).to eq('expired')
      expect(schedule.reload.available_seats).to eq(11)
    end
  end

  context 'when the payment status cannot be fetched' do
    before { gateway.fail_fetch = true }

    it 'keeps the hold and queues itself again' do
      expect { run }.to have_enqueued_job(described_class).with(reservation.id, 1)

      expect(reservation.reload.status).to eq('pending_payment')
      expect(gateway.calls[:cancel_payment]).to be_empty
    end

    it 'expires after the last attempt' do
      run(5)

      expect(reservation.reload.status).to eq('expired')
      expect(schedule.reload.available_seats).to eq(11)
    end
  end

  context 'when the gateway is not configured' do
    before do
      Payments::Gateway.current = nil
      allow(Payments::Gateway).to receive(:current).and_raise(Payments::NotConfigured, 'HYPERSWITCH_URL is not set')
    end

    it 'keeps the hold and queues itself again instead of expiring' do
      expect { run }.to have_enqueued_job(described_class).with(reservation.id, 1)

      expect(reservation.reload.status).to eq('pending_payment')
      expect(schedule.reload.available_seats).to eq(10)
    end

    it 'expires without a gateway call after the last attempt' do
      expect { run(5) }.not_to have_enqueued_job(described_class)

      expect(reservation.reload.status).to eq('expired')
      expect(payment.reload.status).to eq('requires_payment_method')
    end
  end

  %w[confirmed cancelled expired].each do |status|
    context "when the reservation is already #{status}" do
      let(:reservation_status) { status }

      it 'changes nothing and calls no gateway' do
        expect { run }.not_to have_enqueued_job(described_class)

        expect(reservation.reload.status).to eq(status)
        expect(schedule.reload.available_seats).to eq(10)
        expect(payment.reload.status).to eq('requires_payment_method')
        expect(gateway.calls).to be_empty
      end
    end
  end

  it 'does nothing when the reservation no longer exists' do
    expect { described_class.perform_now(0) }.not_to raise_error
    expect(gateway.calls).to be_empty
  end

  it 'defaults to the first attempt when queued with only the reservation id' do
    gateway.payment_status = 'processing'

    expect { described_class.perform_now(reservation.id) }
      .to have_enqueued_job(described_class).with(reservation.id, 1)
  end
end
