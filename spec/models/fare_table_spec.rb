# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FareTable do
  describe '.active_on' do
    let(:city) { create(:city) }

    it 'returns the latest active table effective on or before the date' do
      create(:fare_table, city: city, effective_from: Date.new(2026, 1, 1))
      newer = create(:fare_table, city: city, effective_from: Date.new(2026, 6, 1))
      create(:fare_table, city: city, effective_from: Date.new(2026, 12, 1))

      expect(described_class.active_on(city, 'non_ac', Date.new(2026, 6, 1))).to eq(newer)
    end

    it 'ignores inactive tables, other service classes and other cities' do
      older = create(:fare_table, city: city, effective_from: Date.new(2026, 1, 1))
      create(:fare_table, city: city, effective_from: Date.new(2026, 6, 1), active: false)
      create(:fare_table, city: city, service_class: 'ac', effective_from: Date.new(2026, 6, 1))
      create(:fare_table, effective_from: Date.new(2026, 6, 1))

      expect(described_class.active_on(city, 'non_ac', Date.new(2026, 7, 1))).to eq(older)
    end

    it 'returns nil when no table is effective yet' do
      create(:fare_table, city: city, effective_from: Date.new(2026, 6, 1))

      expect(described_class.active_on(city, 'non_ac', Date.new(2026, 5, 31))).to be_nil
    end
  end
end
