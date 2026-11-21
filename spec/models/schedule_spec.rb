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
