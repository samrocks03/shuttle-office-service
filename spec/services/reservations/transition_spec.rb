# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reservations::Transition do
  include ActiveJob::TestHelper

  let(:schedule) { create(:schedule, available_seats: 10) }
  let(:reservation) { create(:reservation, schedule: schedule, status: status) }
  let(:status) { 'pending_payment' }

  def call(to)
    described_class.call(reservation, to: to, reason: 'spec')
  end

  describe 'allowed moves' do
    it 'moves pending_payment to confirmed' do
      expect(call('confirmed')).to be true
      expect(reservation.reload.status).to eq('confirmed')
    end

    it 'moves pending_payment to expired' do
      expect(call('expired')).to be true
      expect(reservation.reload.status).to eq('expired')
    end

    it 'moves pending_payment to cancelled and sets cancelled_at' do
      expect(call('cancelled')).to be true
      reservation.reload
      expect(reservation.status).to eq('cancelled')
      expect(reservation.cancelled_at).to be_within(5.seconds).of(Time.current)
    end

    context 'when confirmed' do
      let(:status) { 'confirmed' }

      it 'moves confirmed to cancelled and sets cancelled_at' do
        expect(call('cancelled')).to be true
        reservation.reload
        expect(reservation.status).to eq('cancelled')
        expect(reservation.cancelled_at).to be_present
      end
    end

    it 'accepts symbols for the target state' do
      expect(call(:expired)).to be true
      expect(reservation.reload.status).to eq('expired')
    end
  end

  describe 'disallowed moves' do
    [
      %w[confirmed expired],
      %w[confirmed pending_payment],
      %w[confirmed confirmed],
      %w[expired confirmed],
      %w[expired cancelled],
      %w[expired expired],
      %w[cancelled cancelled],
      %w[cancelled confirmed]
    ].each do |from, to|
      it "returns false and changes nothing for #{from} -> #{to}" do
        res = create(:reservation, schedule: schedule, status: from, cancelled_at: nil)

        expect do
          expect(described_class.call(res, to: to, reason: 'spec')).to be false
        end.not_to have_enqueued_job(ReservationConfirmationJob)

        expect(res.reload.status).to eq(from)
        expect(res.cancelled_at).to be_nil
        expect(schedule.reload.available_seats).to eq(10)
      end
    end

    it 'returns false for pending_payment to pending_payment' do
      expect(call('pending_payment')).to be false
      expect(reservation.reload.status).to eq('pending_payment')
    end

    it 'returns false for an unknown state' do
      expect(call('bogus')).to be false
      expect(reservation.reload.status).to eq('pending_payment')
    end
  end

  describe 'side effects' do
    it 'enqueues the confirmation email exactly once on confirm' do
      expect { call('confirmed') }
        .to have_enqueued_job(ReservationConfirmationJob).with(reservation.id).exactly(:once)
    end

    it 'does not enqueue the confirmation email on expire or cancel' do
      expect { call('expired') }.not_to have_enqueued_job(ReservationConfirmationJob)
    end

    it 'gives the seat back on expire' do
      reservation
      schedule.decrement_available_seat!

      expect { call('expired') }.to change { schedule.reload.available_seats }.from(9).to(10)
    end

    it 'gives the seat back on cancel from pending_payment' do
      reservation
      schedule.decrement_available_seat!

      expect { call('cancelled') }.to change { schedule.reload.available_seats }.from(9).to(10)
    end

    it 'gives the seat back on cancel from confirmed' do
      reservation.update!(status: 'confirmed')
      schedule.decrement_available_seat!

      expect { call('cancelled') }.to change { schedule.reload.available_seats }.from(9).to(10)
    end

    it 'does not touch seats on confirm' do
      expect { call('confirmed') }.not_to(change { schedule.reload.available_seats })
    end

    # Specs run inside a transactional fixture whose wrapping transaction is not joinable, so the
    # transaction opened by with_lock (or by an explicit Reservation.transaction) is a real savepoint
    # transaction and after_commit callbacks fire when it commits. No special test setup is needed.
    it 'queues no email and keeps pending_payment when an outer transaction rolls back' do
      reservation # create before the transaction that gets rolled back
      expect do
        Reservation.transaction do
          expect(call('confirmed')).to be true
          raise ActiveRecord::Rollback
        end
      end.not_to have_enqueued_job(ReservationConfirmationJob)

      expect(reservation.reload.status).to eq('pending_payment')
    end

    it 'queues the email once when an outer transaction commits' do
      expect do
        Reservation.transaction { call('confirmed') }
      end.to have_enqueued_job(ReservationConfirmationJob).with(reservation.id).exactly(:once)
    end

    it 'does not queue the email for a rejected move' do
      confirmed = create(:reservation, schedule: schedule, status: 'confirmed')

      expect { described_class.call(confirmed, to: 'confirmed', reason: 'spec') }
        .not_to have_enqueued_job(ReservationConfirmationJob)
    end
  end
end
