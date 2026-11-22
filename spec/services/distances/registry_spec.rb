# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Distances::Registry do
  it 'fetches registered providers by name' do
    expect(described_class.fetch('osrm')).to be_a(Distances::Osrm)
    expect(described_class.fetch('haversine')).to be_a(Distances::Haversine)
  end

  it 'raises UnknownProvider for an unknown name' do
    expect { described_class.fetch('google') }.to raise_error(Distances::UnknownProvider, /google/)
  end
end
