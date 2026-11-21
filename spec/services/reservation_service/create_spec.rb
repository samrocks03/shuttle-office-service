# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationService::Create do
  include ActiveJob::TestHelper

  it 'queues exactly one confirmation email for a free booking' do
    user = create(:user)
    schedule = create(:schedule, available_seats: 5)

    result = nil
    expect do
      result = described_class.new({ schedule_id: schedule.id }, { user_id: user.id }).call
    end.to have_enqueued_job(ReservationConfirmationJob).exactly(:once)

    expect(result.success).to be true
    expect(Reservation.last.status).to eq('confirmed')
  end
end
