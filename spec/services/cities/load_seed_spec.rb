# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Cities::LoadSeed do
  let(:path) { Rails.root.join('db/seeds/cities/pune.yml') }

  # Hinjewadi Phase 3 (OSM node) lies at lng ~73.687, just west of the 73.70 edge the plan suggested.
  let(:latitude_range) { 18.40..18.70 }
  let(:longitude_range) { 73.65..74.00 }

  describe '#call' do
    it 'returns the Pune city configured for OSRM with payments off' do
      city = described_class.new(path).call

      expect(city).to have_attributes(
        name: 'Pune', country_code: 'IN', currency: 'INR', time_zone: 'Asia/Kolkata',
        distance_provider: 'osrm', payments_enabled: false
      )
    end

    it 'creates 12 pickups and 6 offices' do
      city = described_class.new(path).call

      expect(city.stops.pickups.count).to eq(12)
      expect(city.stops.offices.count).to eq(6)
    end

    it 'places every stop inside the Pune bounding box and records its OSM reference' do
      city = described_class.new(path).call

      city.stops.each do |stop|
        expect(latitude_range).to cover(stop.latitude), "#{stop.name} latitude #{stop.latitude}"
        expect(longitude_range).to cover(stop.longitude), "#{stop.name} longitude #{stop.longitude}"
        expect(stop.osm_ref).to match(%r{\A(node|way|relation)/\d+\z})
      end
    end

    it 'is idempotent: loading twice leaves one city, 18 stops and unchanged rows' do
      described_class.new(path).call
      snapshot = Stop.order(:id).pluck(:id, :name, :latitude, :longitude, :osm_ref, :updated_at)

      expect { described_class.new(path).call }.not_to change { [City.count, Stop.count] }
      expect(City.count).to eq(1)
      expect(Stop.count).to eq(18)
      expect(Stop.order(:id).pluck(:id, :name, :latitude, :longitude, :osm_ref, :updated_at)).to eq(snapshot)
    end

    it 'reuses an existing city whose name differs only by case' do
      existing = create(:city, name: 'pune')

      city = described_class.new(path).call

      expect(city).to eq(existing)
      expect(City.count).to eq(1)
      expect(city.reload).to have_attributes(country_code: 'IN', distance_provider: 'osrm')
    end

    it 'updates a stop that already exists by name instead of duplicating it' do
      city = described_class.new(path).call
      wakad = city.stops.find_by!(name: 'Wakad')
      wakad.update!(latitude: 18.5, longitude: 73.8)

      expect { described_class.new(path).call }.not_to change(Stop, :count)
      expect(wakad.reload.latitude).to be_within(0.0001).of(18.602249)
    end

    it 'enqueues the distance job only when a stop is created' do
      expect { described_class.new(path).call }.to have_enqueued_job(ComputeCityDistancesJob).exactly(18).times

      expect { described_class.new(path).call }.not_to have_enqueued_job(ComputeCityDistancesJob)
    end
  end
end
