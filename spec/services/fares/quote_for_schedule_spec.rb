# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fares::QuoteForSchedule do
  let(:city) { create(:city) }
  let(:company) { create(:company, city: city) }
  let(:bus) { create(:bus, company: company, service_class: 'ac') }
  let(:from_stop) { create(:stop, city: city) }
  let(:to_stop) { create(:stop, :office, city: city) }
  let(:date) { Date.new(2026, 12, 15) }
  let(:schedule) { create(:schedule, bus: bus, date: date, from_stop: from_stop, to_stop: to_stop) }
  let!(:stop_distance) { create(:stop_distance, from_stop: from_stop, to_stop: to_stop, computed_km: 18.4) }
  let!(:ac_table) { create(:fare_table, :best_ac, city: city, effective_from: Date.new(2026, 12, 1)) }
  let!(:non_ac_table) { create(:fare_table, :best_non_ac, city: city, effective_from: Date.new(2026, 12, 1)) }

  subject(:service) { described_class.new(schedule) }

  describe '#call' do
    it 'prices an AC bus over 18.4 km at 35 rupees in INR' do
      quote = service.call

      expect(quote).to be_a(Fares::Quote)
      expect(quote).to have_attributes(amount_minor: 3500, currency: 'INR', slab_label: 'up to 20 km',
                                       fare_table_id: ac_table.id)
      expect(quote.distance_km).to eq(BigDecimal('18.4'))
      expect(service.reason).to be_nil
    end

    it 'uses the fare table of the bus service class' do
      bus.update!(service_class: 'non_ac')

      expect(service.call).to have_attributes(amount_minor: 3000, fare_table_id: non_ac_table.id)
    end

    it 'uses override_km instead of computed_km when it is set' do
      stop_distance.update!(override_km: 4.2)

      quote = service.call

      expect(quote).to have_attributes(amount_minor: 1200, slab_label: 'up to 5 km')
      expect(quote.distance_km).to eq(BigDecimal('4.2'))
    end

    it 'uses the table in force on the schedule date, not a later one' do
      later = create(:fare_table, city: city, service_class: 'ac', effective_from: Date.new(2027, 1, 1))
      create(:fare_slab, fare_table: later, up_to_km: 50, amount_minor: 9900)

      expect(service.call).to have_attributes(amount_minor: 3500, fare_table_id: ac_table.id)
    end

    it 'lets a misconfigured fare table raise instead of hiding it' do
      ac_table.fare_slabs.destroy_all

      expect { service.call }.to raise_error(ArgumentError, /no slabs/)
    end
  end

  describe 'reasons for no quote' do
    it 'is :no_city when the company has no city' do
      company.update!(city: nil)

      expect(service.call).to be_nil
      expect(service.reason).to eq(:no_city)
    end

    it 'is :no_stops when the schedule has no stops' do
      schedule.update!(from_stop: nil, to_stop: nil)

      expect(service.call).to be_nil
      expect(service.reason).to eq(:no_stops)
    end

    it 'is :no_stops when only one stop is set' do
      schedule.update!(to_stop: nil)

      expect(service.call).to be_nil
      expect(service.reason).to eq(:no_stops)
    end

    it 'is :no_distance when the stop pair has no distance row' do
      stop_distance.destroy!

      expect(service.call).to be_nil
      expect(service.reason).to eq(:no_distance)
    end

    it 'is :no_distance when the distance row has neither computed nor override km' do
      stop_distance.update!(computed_km: nil, override_km: nil)

      expect(service.call).to be_nil
      expect(service.reason).to eq(:no_distance)
    end

    it 'is :no_fare_table when no table is in force for the date and class' do
      schedule.update_columns(date: Date.new(2026, 11, 30))

      expect(service.call).to be_nil
      expect(service.reason).to eq(:no_fare_table)
    end

    it 'checks the pieces in order: no city wins over no stops' do
      company.update!(city: nil)
      schedule.update!(from_stop: nil, to_stop: nil)

      expect(service.call).to be_nil
      expect(service.reason).to eq(:no_city)
    end
  end
end
