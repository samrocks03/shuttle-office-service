# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Schedule, type: :model do
  describe '#stop_distance' do
    it 'finds the row for its from and to stops' do
      distance = create(:stop_distance)
      schedule = create(:schedule, from_stop: distance.from_stop, to_stop: distance.to_stop)

      expect(schedule.stop_distance).to eq(distance)
    end

    it 'is nil without stops' do
      expect(create(:schedule).stop_distance).to be_nil
    end
  end

  describe '#departs_at' do
    it 'combines date and departure time in the city time zone' do
      company = create(:company, city: create(:city, time_zone: 'Asia/Kolkata'))
      schedule = create(:schedule, bus: create(:bus, company: company), date: Date.new(2026, 12, 1),
                                   departure_time: '10:00', arrival_time: '11:00')

      expect(schedule.departs_at).to eq(Time.utc(2026, 12, 1, 4, 30))
      expect(schedule.departs_at.time_zone.name).to eq('Asia/Kolkata')
    end

    it 'uses the application time zone when there is no city' do
      schedule = create(:schedule, date: Date.new(2026, 12, 1), departure_time: '10:00', arrival_time: '11:00')

      expect(schedule.departs_at).to eq(Time.zone.local(2026, 12, 1, 10, 0))
    end
  end

  describe '#city' do
    it 'comes from the bus company' do
      city = create(:city)
      company = create(:company, city: city)
      schedule = create(:schedule, bus: create(:bus, company: company))

      expect(schedule.city).to eq(city)
    end

    it 'is nil when the company has no city' do
      expect(create(:schedule).city).to be_nil
    end
  end
end
