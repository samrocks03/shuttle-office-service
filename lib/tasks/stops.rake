# frozen_string_literal: true

namespace :stops do
  desc 'Compute and store distances for every active stop pair in a city: stops:compute_distances[pune]'
  task :compute_distances, [:city] => :environment do |_task, args|
    name = args[:city].to_s.strip
    abort 'Usage: bin/rails "stops:compute_distances[city_name]"' if name.empty?

    city = City.find_by('LOWER(name) = ?', name.downcase)
    abort "City not found: #{name}" unless city

    puts Distances::ComputeForCity.new(city).call
  end
end
