# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reservation do
  describe 'status' do
    it 'defaults to confirmed' do
      reservation = create(:reservation)

      expect(reservation.reload.status).to eq('confirmed')
    end

    it 'has exactly the four string-backed states' do
      expect(described_class.statuses).to eq(
        'confirmed' => 'confirmed', 'pending_payment' => 'pending_payment',
        'cancelled' => 'cancelled', 'expired' => 'expired'
      )
    end

    it 'defaults the hold duration to 10 minutes' do
      expect(described_class::HOLD_DURATION).to eq(10.minutes)
    end
  end

  describe 'one active booking per user and schedule' do
    let(:user) { create(:user) }
    let(:schedule) { create(:schedule) }

    it 'rejects a second confirmed booking with the existing message' do
      create(:reservation, user: user, schedule: schedule)
      duplicate = build(:reservation, user: user, schedule: schedule)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:schedule_id]).to include('is already booked')
    end

    it 'rejects a pending_payment booking when a confirmed one exists' do
      create(:reservation, user: user, schedule: schedule, status: 'confirmed')
      duplicate = build(:reservation, user: user, schedule: schedule, status: 'pending_payment')

      expect(duplicate).not_to be_valid
    end

    it 'rejects two active bookings at the database level' do
      create(:reservation, user: user, schedule: schedule, status: 'pending_payment')
      duplicate = build(:reservation, user: user, schedule: schedule, status: 'confirmed')

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    %w[expired cancelled].each do |status|
      it "allows booking again after a #{status} reservation" do
        create(:reservation, user: user, schedule: schedule, status: status)
        again = build(:reservation, user: user, schedule: schedule, status: 'pending_payment')

        expect(again).to be_valid
        expect { again.save! }.not_to raise_error
      end
    end

    it 'allows several inactive reservations for the same user and schedule' do
      create(:reservation, user: user, schedule: schedule, status: 'expired')
      create(:reservation, user: user, schedule: schedule, status: 'cancelled')

      expect(described_class.where(user: user, schedule: schedule).count).to eq(2)
    end

    it 'does not count the record itself when it is updated' do
      reservation = create(:reservation, user: user, schedule: schedule)

      expect(reservation).to be_valid
    end
  end

  describe '#open_payments and #succeeded_payment' do
    let(:reservation) { create(:reservation, status: 'pending_payment') }

    it 'returns only payments in an open status' do
      open_one = create(:payment, reservation: reservation, status: 'requires_payment_method')
      processing = create(:payment, reservation: reservation, status: 'processing')
      create(:payment, reservation: reservation, status: 'failed')
      create(:payment, reservation: reservation, status: 'succeeded')

      expect(reservation.open_payments).to contain_exactly(open_one, processing)
    end

    it 'returns the succeeded payment, or nil' do
      expect(reservation.succeeded_payment).to be_nil

      create(:payment, reservation: reservation, status: 'failed')
      winner = create(:payment, reservation: reservation, status: 'succeeded')

      expect(reservation.succeeded_payment).to eq(winner)
    end
  end

  describe 'fare table guard' do
    it 'refuses to update a fare table used by a reservation' do
      table = create(:fare_table)
      create(:reservation, fare_table: table)

      expect { table.update!(active: false) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'refuses to destroy a fare table used by a reservation' do
      table = create(:fare_table)
      create(:reservation, fare_table: table)

      expect { table.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(FareTable.exists?(table.id)).to be true
    end

    it 'still allows changing an unused fare table' do
      table = create(:fare_table)

      expect { table.update!(active: false) }.not_to raise_error
    end
  end
end
