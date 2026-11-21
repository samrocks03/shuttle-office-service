# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SchedulesController do
  it 'counts only active reservations against the bus capacity' do
    schedule = create(:schedule, bus: create(:bus, capacity: 10))
    create(:reservation, schedule: schedule, status: 'confirmed')
    create(:reservation, schedule: schedule, status: 'pending_payment')
    create(:reservation, schedule: schedule, status: 'expired')

    expect(described_class.new.send(:schedule_json, schedule)[:available_seats]).to eq(8)
  end
end
