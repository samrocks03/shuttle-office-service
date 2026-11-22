# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Distances::ComputeForCity do
  let(:city) { create(:city, distance_provider: 'haversine') }
  let!(:pickup_a) { create(:stop, city: city) }
  let!(:pickup_b) { create(:stop, city: city) }
  let!(:office) { create(:stop, :office, city: city) }

  # Fake provider: every cell is (10 + row + column * 0.5) km, 20 minutes.
  let(:provider) do
    Class.new do
      attr_reader :calls

      def initialize(km_offset: 0, cells: nil)
        @km_offset = km_offset
        @cells = cells
        @calls = []
      end

      def matrix(sources:, destinations:)
        @calls << [sources.map(&:id), destinations.map(&:id)]
        return @cells.call(sources, destinations) if @cells

        sources.each_index.map do |row|
          destinations.each_index.map { |col| Distances::Cell.new(@km_offset + 10 + row + (col * 0.5), 20) }
        end
      end
    end
  end

  def run(provider_instance = provider.new)
    described_class.new(city, provider: provider_instance).call
  end

  it 'stores both directions for every pickup and office pair' do
    result = run

    expect(result).to eq(pairs: 4, unrouted: 0)
    expect(StopDistance.count).to eq(4)
    expect(StopDistance.between(pickup_a, office).computed_km).to eq(10)
    expect(StopDistance.between(pickup_b, office).computed_km).to eq(11)
    expect(StopDistance.between(office, pickup_a).computed_km).to eq(10)
    expect(StopDistance.between(office, pickup_b).computed_km).to eq(10.5)
  end

  it 'records minutes, source and computed_at' do
    run

    row = StopDistance.between(pickup_a, office)
    expect(row.computed_minutes).to eq(20)
    expect(row.source).to eq('haversine')
    expect(row.computed_at).to be_within(1.minute).of(Time.current)
    expect(row.uid).to be_present
  end

  it 'updates computed values on a second run and leaves overrides untouched' do
    run
    existing = StopDistance.between(pickup_a, office)
    existing.update!(override_km: 17.0, override_reason: 'toll road')

    result = run(provider.new(km_offset: 100))

    expect(result).to eq(pairs: 4, unrouted: 0)
    expect(StopDistance.count).to eq(4)
    existing.reload
    expect(existing.computed_km).to eq(110)
    expect(existing.override_km).to eq(17.0)
    expect(existing.override_reason).to eq('toll road')
  end

  it 'stores unrouted pairs with nil computed_km and counts them' do
    cells = lambda do |sources, destinations|
      sources.map { destinations.map { Distances::Cell.new(nil, nil) } }
    end

    result = run(provider.new(cells: cells))

    expect(result).to eq(pairs: 4, unrouted: 4)
    row = StopDistance.between(pickup_a, office)
    expect(row).to be_present
    expect(row.computed_km).to be_nil
    expect(row.computed_minutes).to be_nil
  end

  it 'excludes inactive stops' do
    inactive = create(:stop, city: city, active: false)

    result = run

    expect(result).to eq(pairs: 4, unrouted: 0)
    expect(StopDistance.where(from_stop_id: inactive.id).or(StopDistance.where(to_stop_id: inactive.id))).to be_empty
  end

  it 'ignores stops from other cities' do
    other = create(:city)
    create(:stop, city: other)
    create(:stop, :office, city: other)

    expect(run).to eq(pairs: 4, unrouted: 0)
  end

  it 'skips the provider when a side is empty' do
    office.update!(active: false)
    fake = provider.new

    expect(run(fake)).to eq(pairs: 0, unrouted: 0)
    expect(fake.calls).to be_empty
    expect(StopDistance.count).to eq(0)
  end

  it 'resolves the provider from the registry by default' do
    result = described_class.new(city).call

    expect(result[:pairs]).to eq(4)
    expect(StopDistance.pluck(:source).uniq).to eq(['haversine'])
  end
end
