# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StopDistance, type: :model do
  describe '#effective_km' do
    it 'prefers override_km' do
      distance = build(:stop_distance, computed_km: 18.4, override_km: 17.0)

      expect(distance.effective_km).to eq(BigDecimal('17.0'))
    end

    it 'falls back to computed_km' do
      distance = build(:stop_distance, computed_km: 18.4, override_km: nil)

      expect(distance.effective_km).to eq(BigDecimal('18.4'))
    end

    it 'is nil when neither km is present' do
      distance = build(:stop_distance, computed_km: nil, override_km: nil)

      expect(distance.effective_km).to be_nil
    end
  end

  describe '.between' do
    it 'returns the row for the ordered pair' do
      distance = create(:stop_distance)

      expect(described_class.between(distance.from_stop, distance.to_stop)).to eq(distance)
    end

    it 'returns nil for an unknown pair' do
      distance = create(:stop_distance)

      expect(described_class.between(distance.to_stop, distance.from_stop)).to be_nil
    end
  end

  describe 'constraints' do
    it 'rejects a pair of the same stop' do
      stop = create(:stop)

      expect { create(:stop_distance, from_stop: stop, to_stop: stop) }
        .to raise_error(ActiveRecord::StatementInvalid, /check/i)
    end

    it 'rejects a duplicate ordered pair' do
      existing = create(:stop_distance)
      duplicate = build(:stop_distance, from_stop: existing.from_stop, to_stop: existing.to_stop)

      expect(duplicate).not_to be_valid
    end
  end
end
