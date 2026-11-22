# frozen_string_literal: true

namespace :cities do
  desc 'Load a city seed from db/seeds/cities/<name>.yml and compute its stop distances: cities:load[pune]'
  task :load, [:name] => :environment do |_task, args|
    name = args[:name].to_s.strip.downcase
    abort 'Usage: bin/rails "cities:load[name]"' unless name.match?(/\A[a-z0-9_-]+\z/)

    path = Rails.root.join('db', 'seeds', 'cities', "#{name}.yml")
    abort "Seed file not found: #{path}" unless path.exist?

    city = Cities::LoadSeed.new(path).call
    puts "Loaded #{city.name}: #{city.stops.count} stops"
    puts Distances::ComputeForCity.new(city).call
  end
end
