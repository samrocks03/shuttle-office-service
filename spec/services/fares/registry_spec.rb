# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Fares::Registry do
  it 'fetches the slab policy by name' do
    expect(described_class.fetch('slab')).to be_a(Fares::SlabPolicy)
  end

  it 'raises UnknownPolicy for an unknown name' do
    expect { described_class.fetch('flat') }.to raise_error(Fares::UnknownPolicy, /flat/)
  end
end
