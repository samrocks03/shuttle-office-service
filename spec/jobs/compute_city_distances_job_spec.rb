# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ComputeCityDistancesJob do
  include ActiveJob::TestHelper

  let(:city) { create(:city, distance_provider: 'haversine') }

  describe 'Stop after_commit trigger' do
    before { city }

    it 'enqueues when a stop is created' do
      expect { create(:stop, city: city) }
        .to have_enqueued_job(described_class).with(city.id)
    end

    it 'enqueues when coordinates change' do
      stop = create(:stop, city: city)
      clear_enqueued_jobs

      expect { stop.update!(latitude: 18.6) }.to have_enqueued_job(described_class).with(city.id)
    end

    it 'enqueues when a stop becomes active' do
      stop = create(:stop, city: city, active: false)
      clear_enqueued_jobs

      expect { stop.update!(active: true) }.to have_enqueued_job(described_class).with(city.id)
    end

    it 'does not enqueue for unrelated changes or deactivation' do
      stop = create(:stop, city: city)
      clear_enqueued_jobs

      expect { stop.update!(name: 'Renamed') }.not_to have_enqueued_job(described_class)
      expect { stop.update!(active: false) }.not_to have_enqueued_job(described_class)
    end
  end

  describe '#perform' do
    it 'computes distances for the city' do
      create(:stop, city: city)
      create(:stop, :office, city: city)

      expect { described_class.perform_now(city.id) }.to change(StopDistance, :count).by(2)
    end

    it 'is discarded when the city no longer exists' do
      expect { described_class.perform_now(0) }.not_to raise_error
    end
  end
end
