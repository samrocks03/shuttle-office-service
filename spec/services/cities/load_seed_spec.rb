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

    describe 'fares' do
      let(:city) { described_class.new(path).call }
      let(:non_ac) { city.fare_tables.find_by!(service_class: 'non_ac') }
      let(:ac) { city.fare_tables.find_by!(service_class: 'ac') }

      def slabs(table)
        table.fare_slabs.reload.map { |slab| [slab.up_to_km.to_i, slab.amount_minor] }
      end

      it 'creates a non-AC and an AC table effective from 1 December 2026 with 5 km / 500 steps' do
        expect(city.fare_tables.count).to eq(2)
        expect([non_ac, ac]).to all(have_attributes(
          currency: 'INR', policy: 'slab', effective_from: Date.new(2026, 12, 1), active: true,
          step_km: 5, step_amount_minor: 500
        ))
      end

      it 'loads the BEST non-AC and AC slabs in paise' do
        expect(slabs(non_ac)).to eq([[5, 1000], [10, 1500], [15, 2000], [20, 3000], [25, 3500],
                                     [30, 4000], [35, 4500], [40, 5000], [45, 5500], [50, 6000]])
        expect(slabs(ac)).to eq([[5, 1200], [10, 2000], [15, 3000], [20, 3500], [25, 4000],
                                 [30, 4500], [35, 5000], [40, 5500], [45, 6000], [50, 6500]])
      end

      it 'prices 18.4 km at 35 rupees AC and 30 rupees non-AC' do
        policy = Fares::Registry.fetch('slab')

        expect(policy.price(distance_km: 18.4, fare_table: ac).amount_minor).to eq(3500)
        expect(policy.price(distance_km: 18.4, fare_table: non_ac).amount_minor).to eq(3000)
      end

      it 'is idempotent: a second load adds no tables or slabs and touches none' do
        city
        snapshot = [FareTable.order(:id).pluck(:id, :updated_at), FareSlab.order(:id).pluck(:id, :amount_minor, :updated_at)]

        expect { described_class.new(path).call }.not_to change { [FareTable.count, FareSlab.count] }
        expect([FareTable.order(:id).pluck(:id, :updated_at),
                FareSlab.order(:id).pluck(:id, :amount_minor, :updated_at)]).to eq(snapshot)
      end

      it 'does not change a table that already has slabs' do
        city
        non_ac.fare_slabs.find_by!(up_to_km: 5).update!(amount_minor: 1111)
        non_ac.update!(step_amount_minor: 700)

        described_class.new(path).call

        expect(non_ac.reload.step_amount_minor).to eq(700)
        expect(non_ac.fare_slabs.find_by!(up_to_km: 5).amount_minor).to eq(1111)
        expect(non_ac.fare_slabs.count).to eq(10)
      end

      it 'fills the slabs of an existing table that has none' do
        city
        non_ac.fare_slabs.destroy_all

        described_class.new(path).call

        expect(slabs(non_ac.reload).first).to eq([5, 1000])
        expect(non_ac.fare_slabs.count).to eq(10)
        expect(FareTable.count).to eq(2)
      end

      it 'adds a new table instead of editing when the effective date differs' do
        city
        non_ac.update!(effective_from: Date.new(2026, 6, 1))

        described_class.new(path).call

        expect(city.fare_tables.where(service_class: 'non_ac').order(:effective_from).pluck(:effective_from))
          .to eq([Date.new(2026, 6, 1), Date.new(2026, 12, 1)])
        expect(non_ac.reload.fare_slabs.count).to eq(10)
      end
    end

    it 'enqueues the distance job only when a stop is created' do
      expect { described_class.new(path).call }.to have_enqueued_job(ComputeCityDistancesJob).exactly(18).times

      expect { described_class.new(path).call }.not_to have_enqueued_job(ComputeCityDistancesJob)
    end
  end
end
