# frozen_string_literal: true

module Cities
  # Loads a city seed file (db/seeds/cities/<name>.yml): finds or creates the city by name
  # (case-insensitive) and upserts its stops by (city, name). Stops are saved one by one so
  # model callbacks run, and a second load of an unchanged file changes nothing.
  #
  # Fare tables are versioned: one is found by (city, service_class, effective_from) and its slabs
  # are loaded only while it has none. A table that already has slabs is never changed; to change
  # prices, add a table with a later effective_from.
  class LoadSeed
    STOP_ATTRIBUTES = %w[kind latitude longitude osm_ref].freeze
    FARE_TABLE_ATTRIBUTES = %w[currency policy step_km step_amount_minor].freeze

    def initialize(path)
      @path = path
    end

    def call
      data = YAML.safe_load_file(@path)

      City.transaction do
        city = upsert_city(data.fetch('city'))
        data.fetch('stops').each { |stop| upsert_stop(city, stop) }
        data.fetch('fares', []).each { |fare| load_fare_table(city, fare) }
        city
      end
    end

    private

    def upsert_city(attributes)
      city = City.find_by('LOWER(name) = ?', attributes.fetch('name').downcase) || City.new
      city.update!(attributes)
      city
    end

    def upsert_stop(city, attributes)
      stop = city.stops.find_or_initialize_by(name: attributes.fetch('name'))
      stop.update!(attributes.slice(*STOP_ATTRIBUTES))
    end

    def load_fare_table(city, attributes)
      table = city.fare_tables.find_or_initialize_by(
        service_class: attributes.fetch('service_class'),
        effective_from: Date.iso8601(attributes.fetch('effective_from').to_s)
      )
      return if table.persisted? && table.fare_slabs.exists?

      table.assign_attributes(attributes.slice(*FARE_TABLE_ATTRIBUTES))
      table.save!
      attributes.fetch('slabs').each { |slab| table.fare_slabs.create!(slab.slice('up_to_km', 'amount_minor')) }
    end
  end
end
