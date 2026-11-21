# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fares::SlabPolicy do
  let(:non_ac) { create(:fare_table, :best_non_ac) }
  let(:ac) { create(:fare_table, :best_ac) }

  {
    0.1 => [1000, 1200],
    5.0 => [1000, 1200],
    5.01 => [1500, 2000],
    10 => [1500, 2000],
    15 => [2000, 3000],
    20 => [3000, 3500],
    20.5 => [3500, 4000],
    50 => [6000, 6500],
    50.01 => [6500, 7000],
    73 => [8500, 9000]
  }.each do |km, (non_ac_amount, ac_amount)|
    it "prices #{km} km at #{non_ac_amount} (Non-AC) and #{ac_amount} (AC) paise" do
      expect(described_class.new.price(distance_km: km, fare_table: non_ac).amount_minor).to eq(non_ac_amount)
      expect(described_class.new.price(distance_km: km, fare_table: ac).amount_minor).to eq(ac_amount)
    end
  end

  it 'accepts BigDecimal, Float and Integer distances equivalently' do
    amounts = [BigDecimal('5.0'), 5.0, 5].map { |km| described_class.new.price(distance_km: km, fare_table: non_ac).amount_minor }
    expect(amounts).to all(eq(1000))
    expect(described_class.new.price(distance_km: BigDecimal('5.01'), fare_table: non_ac).amount_minor).to eq(1500)
  end

  it 'returns a Quote with currency, distance, label and fare table id' do
    quote = described_class.new.price(distance_km: 18.4, fare_table: non_ac)

    expect(quote).to be_a(Fares::Quote)
    expect(quote.to_h).to eq(amount_minor: 3000, currency: 'INR', distance_km: BigDecimal('18.4'),
                             slab_label: 'up to 20 km', fare_table_id: non_ac.id)
  end

  it 'labels slabs and beyond-last-slab distances' do
    expect(described_class.new.price(distance_km: 5, fare_table: non_ac).slab_label).to eq('up to 5 km')
    expect(described_class.new.price(distance_km: 50.01, fare_table: non_ac).slab_label).to eq('55 km slab')
    expect(described_class.new.price(distance_km: 73, fare_table: non_ac).slab_label).to eq('75 km slab')
  end

  it 'raises ArgumentError for zero or negative distance' do
    expect { described_class.new.price(distance_km: 0, fare_table: non_ac) }.to raise_error(ArgumentError)
    expect { described_class.new.price(distance_km: -3, fare_table: non_ac) }.to raise_error(ArgumentError)
  end

  it 'raises ArgumentError beyond the last slab when no step is configured' do
    table = create(:fare_table, :best_non_ac, step_km: nil, step_amount_minor: nil)

    expect { described_class.new.price(distance_km: 60, fare_table: table) }.to raise_error(ArgumentError, /step/)
  end
end
