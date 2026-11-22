# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationConfirmationJob do
  include ActiveJob::TestHelper

  before { ActionMailer::Base.deliveries.clear }

  %w[pending_payment expired cancelled].each do |status|
    it "does nothing for a #{status} reservation" do
      reservation = create(:reservation, status: status)
      allow(Pdf::ReservationGenerator).to receive(:new)

      described_class.perform_now(reservation.id)

      expect(Pdf::ReservationGenerator).not_to have_received(:new)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  it 'sends the email for a confirmed reservation' do
    reservation = create(:reservation, status: 'confirmed')

    described_class.perform_now(reservation.id)

    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it 'discards a job whose reservation no longer exists' do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
