# frozen_string_literal: true

module Cities
  # Loads a city seed file (db/seeds/cities/<name>.yml): finds or creates the city by name
  # (case-insensitive) and upserts its stops by (city, name). Stops are saved one by one so
  # model callbacks run, and a second load of an unchanged file changes nothing.
  class LoadSeed
    STOP_ATTRIBUTES = %w[kind latitude longitude osm_ref].freeze

    def initialize(path)
      @path = path
    end

    def call
      data = YAML.safe_load_file(@path)

      City.transaction do
        city = upsert_city(data.fetch('city'))
        data.fetch('stops').each { |stop| upsert_stop(city, stop) }
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
  end
end
