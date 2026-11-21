# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bus, type: :model do
  it 'defaults service_class to non_ac' do
    expect(create(:bus).service_class).to eq('non_ac')
  end

  it 'accepts ac' do
    expect(build(:bus, service_class: 'ac')).to be_valid
  end

  it 'rejects service_class "luxury"' do
    bus = build(:bus, service_class: 'luxury')

    expect(bus).not_to be_valid
    expect(bus.errors[:service_class]).to be_present
  end
end
