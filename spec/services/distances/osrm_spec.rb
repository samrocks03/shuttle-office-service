# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Distances::Osrm do
  let(:base_url) { 'http://osrm.test' }
  let(:fixture) { Rails.root.join('spec/fixtures/osrm/table_2x2.json').read }
  let(:src_a) { build_stubbed(:stop, latitude: 18.5286, longitude: 73.8743) }
  let(:src_b) { build_stubbed(:stop, latitude: 18.5204, longitude: 73.8567) }
  let(:dst_c) { build_stubbed(:stop, latitude: 18.5913, longitude: 73.7389) }
  let(:dst_d) { build_stubbed(:stop, latitude: 18.5600, longitude: 73.8000) }
  let(:provider) { described_class.new(base_url: base_url) }

  describe '#matrix' do
    it 'builds the request with longitude first and source/destination indexes' do
      stub = stub_request(:get, %r{\Ahttp://osrm\.test/table/v1/driving/})
             .to_return(status: 200, body: fixture)

      provider.matrix(sources: [src_a, src_b], destinations: [dst_c, dst_d])

      expect(
        a_request(:get, 'http://osrm.test/table/v1/driving/73.8743,18.5286;73.8567,18.5204;73.7389,18.5913;73.8,18.56')
          .with(query: hash_including('sources' => '0;1', 'destinations' => '2;3',
                                      'annotations' => 'distance,duration'))
      ).to have_been_made.once
      expect(stub).to have_been_requested
    end

    it 'parses km (3 places) and minutes (rounded up) from the response' do
      stub_request(:get, %r{\Ahttp://osrm\.test/table/v1/driving/}).to_return(status: 200, body: fixture)

      matrix = provider.matrix(sources: [src_a, src_b], destinations: [dst_c, dst_d])

      expect(matrix).to eq(
        [
          [Distances::Cell.new(12.345, 21), Distances::Cell.new(8.0, 15)],
          [Distances::Cell.new(5.0, 5), Distances::Cell.new(20.501, 31)]
        ]
      )
    end

    it 'returns an empty cell when OSRM has no route for a pair' do
      body = { code: 'Ok', distances: [[nil, 1000.0]], durations: [[nil, 60.0]] }.to_json
      stub_request(:get, %r{\Ahttp://osrm\.test/table/v1/driving/}).to_return(status: 200, body: body)

      matrix = provider.matrix(sources: [src_a], destinations: [dst_c, dst_d])

      expect(matrix[0][0]).to eq(Distances::Cell.new(nil, nil))
      expect(matrix[0][1]).to eq(Distances::Cell.new(1.0, 1))
    end

    it 'splits into batches within max_coordinates and stitches one full matrix in order' do
      provider = described_class.new(base_url: base_url, max_coordinates: 4)
      sources = [1, 2, 3].map { |n| build_stubbed(:stop, latitude: 18.0, longitude: n) }
      destinations = [11, 12, 13].map { |n| build_stubbed(:stop, latitude: 18.0, longitude: n) }

      # Each cell reports (source_lng * 100 + destination_lng) km, so ordering is verifiable.
      stub_request(:get, %r{\Ahttp://osrm\.test/table/v1/driving/}).to_return do |request|
        coords = request.uri.path.split('/').last.split(';').map { |c| c.split(',').first.to_f }
        query = Rack::Utils.parse_query(request.uri.query)
        srcs = query['sources'].split(';').map(&:to_i)
        dsts = query['destinations'].split(';').map(&:to_i)
        expect(coords.size).to be <= 4
        distances = srcs.map { |s| dsts.map { |d| (coords[s] * 100 + coords[d]) * 1000 } }
        durations = srcs.map { dsts.map { 60.0 } }
        { status: 200, body: { code: 'Ok', distances: distances, durations: durations }.to_json }
      end

      matrix = provider.matrix(sources: sources, destinations: destinations)

      expect(WebMock).to have_requested(:get, %r{osrm\.test/table}).at_least_twice
      expect(matrix.map { |row| row.map(&:km) }).to eq(
        [[111.0, 112.0, 113.0], [211.0, 212.0, 213.0], [311.0, 312.0, 313.0]]
      )
    end

    it 'raises ProviderError when OSRM reports a non-Ok code' do
      stub_request(:get, %r{\Ahttp://osrm\.test/table/v1/driving/})
        .to_return(status: 200, body: { code: 'NoRoute', message: 'no route' }.to_json)

      expect { provider.matrix(sources: [src_a], destinations: [dst_c]) }
        .to raise_error(Distances::ProviderError, /NoRoute/)
    end

    it 'raises ProviderError on an HTTP failure' do
      stub_request(:get, %r{\Ahttp://osrm\.test/table/v1/driving/}).to_return(status: 500, body: 'boom')

      expect { provider.matrix(sources: [src_a], destinations: [dst_c]) }
        .to raise_error(Distances::ProviderError)
    end
  end
end
