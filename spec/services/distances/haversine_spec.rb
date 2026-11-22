# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Distances::Haversine do
  let(:station) { build_stubbed(:stop, latitude: 18.5286, longitude: 73.8743) }
  let(:hinjewadi) { build_stubbed(:stop, latitude: 18.5913, longitude: 73.7389) }

  it 'returns great-circle km multiplied by 1.4 with nil minutes' do
    matrix = described_class.new.matrix(sources: [station], destinations: [hinjewadi])

    expect(matrix.size).to eq(1)
    cell = matrix[0][0]
    expect(cell).to be_a(Distances::Cell)
    expect(cell.km).to be_within(0.5).of(22.2)
    expect(cell.minutes).to be_nil
  end

  it 'returns zero distance for the same point' do
    matrix = described_class.new.matrix(sources: [station], destinations: [station])

    expect(matrix[0][0].km).to eq(0.0)
  end

  it 'returns one row per source and one column per destination' do
    matrix = described_class.new.matrix(sources: [station, hinjewadi], destinations: [station, hinjewadi, station])

    expect(matrix.map(&:size)).to eq([3, 3])
  end
end
