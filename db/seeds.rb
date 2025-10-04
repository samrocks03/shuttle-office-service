# frozen_string_literal: true

puts '*** Starting database seeding...'

seed_path = Rails.root.join('db/seeds')

puts "Seeds files: #{seed_path}"
# Fetch seed files from an environment variable or default to all seed files
# seed_files = ENV.fetch('SEED_FILES', nil)

seed_files = %w[
  role_seed.rb
  company_seed.rb
  bus_seed.rb
  schedule_seed.rb
]

puts "Seed files to run: #{seed_files.join(', ')}"

seed_files.each do |seed_file|
  file_path = seed_path.join(seed_file)

  if File.exist?(file_path)
    begin
      load file_path
      puts "Loaded:  #{seed_file}"
    rescue StandardError => e
      puts "Error loading #{seed_file}: #{e.message}"
    end
  else
    puts "File not found: #{seed_file}"
  end
end
# seed_files.sort.each { |seed_file| load seed_path.join(seed_file) }

puts "\n Database seeding completed!"
puts ' Final counts:'
puts "  - Roles: #{Role.count}"
puts "  - Companies: #{Company.count}"
puts "  - Buses: #{Bus.count}"
puts "  - Schedules: #{Schedule.count}"
