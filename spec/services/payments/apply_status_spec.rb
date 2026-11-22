# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payments::ApplyStatus do
  include ActiveJob::TestHelper

  let(:gateway) { FakeGateway.new }
  let(:schedule) { create(:schedule, available_seats: 10) }
  let(:reservation) { create(:reservation, schedule: schedule, status: reservation_status) }
  let(:reservation_status) { 'pending_payment' }
  let(:payment) do
    create(:payment, reservation: reservation, gateway_payment_id: 'pay_abc', amount_minor: 3500,
                     status: 'requires_payment_method')
  end

  before { Payments::Gateway.current = gateway }

  def apply(status, connector: 'stripe', error: nil, target: payment)
    described_class.new(target, { id: target.gateway_payment_id, status: status, connector: connector,
                                  error: error }).call
  end

  describe 'a succeeded payment' do
    it 'confirms a pending_payment reservation and queues one boarding-pass email' do
      result = nil
      expect { result = apply('succeeded') }
        .to have_enqueued_job(ReservationConfirmationJob).with(reservation.id).exactly(:once)

      expect(result).to eq(:confirmed)
      expect(reservation.reload.status).to eq('confirmed')
      expect(payment.reload).to have_attributes(status: 'succeeded', connector: 'stripe', last_error: nil)
    end

    it 'leaves an already-confirmed reservation unchanged, with no second email' do
      apply('succeeded')

      result = nil
      expect { result = apply('succeeded') }.not_to have_enqueued_job(ReservationConfirmationJob)
      expect(result).to eq(:unchanged)
      expect(reservation.reload.status).to eq('confirmed')
    end

    context 'when the reservation already expired' do
      let(:reservation_status) { 'expired' }

      it 'refunds the full amount once with reason late_success' do
        result = nil
        expect { result = apply('succeeded') }.not_to have_enqueued_job(ReservationConfirmationJob)

        expect(result).to eq(:refunded_late)
        expect(gateway.calls[:create_refund]).to eq([{ payment_id: 'pay_abc', amount_minor: 3500,
                                                       reason: 'late_success' }])
        expect(payment.refunds.sole).to have_attributes(
          gateway_refund_id: 'ref_fake_1', amount_minor: 3500, status: 'pending', reason: 'late_success'
        )
        expect(payment.reload.status).to eq('succeeded')
        expect(reservation.reload.status).to eq('expired')
      end

      it 'does not refund a second time when the same success is applied again' do
        apply('succeeded')

        expect(apply('succeeded', target: Payment.find(payment.id))).to eq(:unchanged)
        expect(gateway.calls[:create_refund].size).to eq(1)
        expect(payment.refunds.count).to eq(1)
      end

      it 'does not refund when a refund for the payment already exists' do
        create_refund_row(payment)

        expect(apply('succeeded')).to eq(:unchanged)
        expect(gateway.calls[:create_refund]).to be_empty
        expect(payment.refunds.count).to eq(1)
      end

      it 'stores a refused refund as failed with the gateway error' do
        gateway.fail_refund = true

        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        expect(apply('succeeded')).to eq(:refunded_late)
        expect(payment.refunds.sole).to have_attributes(
          gateway_refund_id: nil, status: 'failed', reason: 'late_success', last_error: 'refund rejected by connector'
        )
        expect(Rails.logger).to have_received(:error).with(/late_success refund FAILED for payment pay_abc/)
        expect(Rails.logger).not_to have_received(:info).with(/refund requested/)
      end
    end

    context 'when the reservation was cancelled while pending' do
      let(:reservation_status) { 'cancelled' }

      it 'refunds the late success' do
        expect(apply('succeeded')).to eq(:refunded_late)
        expect(payment.refunds.sole.reason).to eq('late_success')
      end
    end

    it 'does not refund a payment that had already confirmed the reservation before it was cancelled' do
      apply('succeeded')
      Reservations::Transition.call(reservation, to: :cancelled, reason: 'spec')

      expect(apply('succeeded', target: Payment.find(payment.id))).to eq(:unchanged)
      expect(gateway.calls[:create_refund]).to be_empty
    end
  end

  describe 'a second payment succeeding for an already-confirmed reservation' do
    let(:second) do
      create(:payment, reservation: reservation, gateway_payment_id: 'pay_second', amount_minor: 3500,
                       status: 'processing')
    end

    before { apply('succeeded') }

    it 'refunds the second payment in full once with reason duplicate_payment' do
      result = nil
      expect { result = apply('succeeded', target: second) }.not_to have_enqueued_job(ReservationConfirmationJob)

      expect(result).to eq(:refunded_duplicate)
      expect(gateway.calls[:create_refund]).to eq([{ payment_id: 'pay_second', amount_minor: 3500,
                                                     reason: 'duplicate_payment' }])
      expect(second.refunds.sole).to have_attributes(reason: 'duplicate_payment', amount_minor: 3500)
      expect(payment.refunds).to be_empty
      expect(reservation.reload).to be_confirmed
    end

    it 'does not refund the duplicate twice' do
      apply('succeeded', target: second)

      expect(apply('succeeded', target: Payment.find(second.id))).to eq(:unchanged)
      expect(gateway.calls[:create_refund].size).to eq(1)
    end

    it 'logs a refused duplicate refund as an error, with ids only' do
      gateway.fail_refund = true
      allow(Rails.logger).to receive(:error)

      expect(apply('succeeded', target: second)).to eq(:refunded_duplicate)

      expect(second.refunds.sole).to have_attributes(status: 'failed', reason: 'duplicate_payment')
      expect(Rails.logger).to have_received(:error).with(/duplicate_payment refund FAILED for payment pay_second/)
      expect(Rails.logger).not_to have_received(:error).with(/rejected by connector/)
    end
  end

  describe 'statuses only move forward' do
    it 'keeps a succeeded payment succeeded when a stale processing status arrives' do
      apply('succeeded')

      expect(apply('processing', error: 'stale', target: Payment.find(payment.id))).to eq(:unchanged)
      expect(payment.reload).to have_attributes(status: 'succeeded', last_error: nil)
      expect(reservation.reload.status).to eq('confirmed')
    end

    it 'keeps a succeeded payment succeeded when a failed status arrives' do
      apply('succeeded')

      expect(apply('failed', target: Payment.find(payment.id))).to eq(:unchanged)
      expect(payment.reload.status).to eq('succeeded')
    end

    it 'does not move a failed payment back to processing' do
      apply('failed', error: 'card declined')

      expect(apply('processing', target: Payment.find(payment.id))).to eq(:unchanged)
      expect(payment.reload).to have_attributes(status: 'failed', last_error: 'card declined')
    end

    it 'still records a success reported after a failure, and confirms' do
      apply('failed', error: 'card declined')

      expect(apply('succeeded', target: Payment.find(payment.id))).to eq(:confirmed)
      expect(payment.reload).to have_attributes(status: 'succeeded', last_error: nil)
    end

    it 'ignores data with no status' do
      expect(apply(nil)).to eq(:unchanged)
      expect(payment.reload.status).to eq('requires_payment_method')
    end
  end

  describe 'a failed payment' do
    it 'stores the failure on the payment and keeps the reservation pending_payment' do
      result = nil
      expect { result = apply('failed', error: 'card declined') }.not_to have_enqueued_job(ReservationConfirmationJob)

      expect(result).to eq(:failed)
      expect(payment.reload).to have_attributes(status: 'failed', last_error: 'card declined', connector: 'stripe')
      expect(reservation.reload.status).to eq('pending_payment')
    end
  end

  describe 'a payment still processing' do
    it 'updates the payment status only' do
      expect(apply('processing')).to eq(:unchanged)
      expect(payment.reload.status).to eq('processing')
      expect(reservation.reload.status).to eq('pending_payment')
    end
  end

  describe 'refund data' do
    it 'sets the status of the matching refund' do
      refund = create_refund_row(payment, gateway_refund_id: 'ref_xyz')

      result = described_class.new(payment, { id: 'pay_abc', refund_id: 'ref_xyz', status: 'succeeded' }).call

      expect(result).to eq(:unchanged)
      expect(refund.reload.status).to eq('succeeded')
      expect(payment.reload.status).to eq('requires_payment_method')
    end

    it 'keeps a succeeded refund succeeded when a stale pending status arrives' do
      refund = create_refund_row(payment, gateway_refund_id: 'ref_xyz')
      refund.update!(status: 'succeeded')

      result = described_class.new(payment, { id: 'pay_abc', refund_id: 'ref_xyz', status: 'pending' }).call

      expect(result).to eq(:unchanged)
      expect(refund.reload.status).to eq('succeeded')
    end

    it 'does not move a failed refund back to pending' do
      refund = create_refund_row(payment, gateway_refund_id: 'ref_xyz')
      refund.update!(status: 'failed')

      described_class.new(payment, { id: 'pay_abc', refund_id: 'ref_xyz', status: 'pending' }).call

      expect(refund.reload.status).to eq('failed')
    end

    it 'ignores a refund this payment does not have' do
      result = described_class.new(payment, { id: 'pay_abc', refund_id: 'ref_unknown', status: 'succeeded' }).call

      expect(result).to eq(:unchanged)
    end
  end

  def create_refund_row(target, gateway_refund_id: 'ref_existing')
    target.refunds.create!(gateway_refund_id: gateway_refund_id, amount_minor: target.amount_minor,
                           status: 'pending', reason: 'reservation_cancelled')
  end
end
