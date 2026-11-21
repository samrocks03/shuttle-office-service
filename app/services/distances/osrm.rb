# frozen_string_literal: true

require 'net/http'
require 'json'

module Distances
  # OSRM /table client. Batches so each request carries at most max_coordinates coordinates.
  class Osrm < Provider
    DEFAULT_URL = 'https://router.project-osrm.org'
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30

    def initialize(base_url: ENV.fetch('OSRM_URL', DEFAULT_URL), max_coordinates: 100)
      super()
      raise ArgumentError, 'max_coordinates must be at least 2' if max_coordinates < 2

      @base_url = base_url.chomp('/')
      @max_coordinates = max_coordinates
    end

    def matrix(sources:, destinations:)
      result = Array.new(sources.size) { Array.new(destinations.size) }
      source_size = [@max_coordinates / 2, 1].max
      destination_size = @max_coordinates - source_size

      sources.each_slice(source_size).with_index do |source_batch, si|
        destinations.each_slice(destination_size).with_index do |destination_batch, di|
          cells = fetch_table(source_batch, destination_batch)
          cells.each_with_index do |row, r|
            row.each_with_index { |cell, c| result[(si * source_size) + r][(di * destination_size) + c] = cell }
          end
        end
      end

      result
    end

    private

    def fetch_table(sources, destinations)
      body = get(table_uri(sources, destinations))
      raise ProviderError, "OSRM error: #{body['code']} #{body['message']}".strip unless body['code'] == 'Ok'

      sources.each_index.map do |row|
        destinations.each_index.map do |col|
          to_cell(body.dig('distances', row, col), body.dig('durations', row, col))
        end
      end
    end

    def table_uri(sources, destinations)
      stops = sources + destinations
      coordinates = stops.map { |stop| "#{stop.longitude.to_f},#{stop.latitude.to_f}" }.join(';')
      source_idx = sources.each_index.to_a.join(';')
      destination_idx = destinations.each_index.map { |i| i + sources.size }.join(';')
      query = "sources=#{source_idx}&destinations=#{destination_idx}&annotations=distance,duration"
      URI("#{@base_url}/table/v1/driving/#{coordinates}?#{query}")
    end

    def get(uri)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                     open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
      raise ProviderError, "OSRM HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
      raise ProviderError, "OSRM request failed: #{e.message}"
    end

    def to_cell(metres, seconds)
      return Cell.new(nil, nil) if metres.nil? || seconds.nil?

      Cell.new((metres / 1000.0).round(3), (seconds / 60.0).ceil)
    end
  end
end
