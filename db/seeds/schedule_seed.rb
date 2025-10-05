# frozen_string_literal: true

puts 'Creating shuttle bus schedules...'

# Check if we have buses first
if Bus.count.zero?
  puts 'XXX No buses found! Please run bus_seed.rb first.'
  exit
end

# Pune IT Park locations and residential areas
start_points = [
  'Shivajinagar Station', 'Swargate Bus Stand', 'Pune Station', 'Kothrud Depot',
  'Warje Terminal', 'Dhankawadi Stand', 'Katraj Bus Stop', 'Hadapsar Terminal',
  'Viman Nagar Corner', 'Kharadi Bypass', 'Wagholi Junction', 'Lohegaon Road',
  'Aundh IT Park', 'Baner Road', 'Balewadi High Street', 'Pashan Circle',
  'Hinjewadi Phase 1 Gate', 'Hinjewadi Phase 2 Gate', 'Hinjewadi Phase 3 Gate',
  'Magarpatta City Gate', 'Kalyani Nagar Junction', 'Koregaon Park',
  'Yerwada Junction', 'Nagpur Road Corner'
]

# IT Park destinations
destinations = [
  'Infosys Campus', 'Wipro Campus', 'TCS Campus', 'Cognizant Campus',
  'Tech Mahindra Campus', 'Capgemini Tower', 'Barclays EON', 'FIS Building',
  'IBM Ozone Park', 'Deloitte ICC', 'Accenture Tower', 'Persistent Systems',
  'Cybage House', 'Zensar EON', 'Deutsche Bank Kharadi', 'HSBC Tower',
  'Google Campus', 'Microsoft Building', 'Amazon Campus', 'Oracle Park'
]

# Time slots for shuttle services
morning_slots = ['06:00', '06:30', '07:00', '07:30', '08:00', '08:30', '09:00']
evening_slots = ['17:00', '17:30', '18:00', '18:30', '19:00', '19:30', '20:00', '20:30']
night_slots = ['21:00', '21:30', '22:00', '22:30']

# Helper method to calculate arrival time
def calculate_arrival_time(departure_time)
  travel_duration = rand(30..90) # minutes
  (Time.parse(departure_time) + travel_duration.minutes).strftime('%H:%M')
end

puts 'Generating schedules for next 30 days...'

begin
  Schedule.transaction do
    total_schedules_created = 0
    batch_size = 1000
    schedules_batch = []

    companies = Company.includes(:buses).all
    puts "Found #{companies.count} companies with buses"

    companies.each do |company|
      company_buses = company.buses
      next if company_buses.empty?

      puts "Creating schedules for #{company.name} (#{company_buses.count} buses)"

      # Pre-calculate company-specific destination
      company_destination = destinations.find { |d| d.include?(company.name.split.first) } || destinations.sample

      # Generate schedules for next 30 days
      (0..29).each do |day_offset|
        date = Date.today + day_offset
        next if date.saturday? || date.sunday? # Skip weekends for corporate shuttles

        company_buses.each do |bus|
          # Morning pickup schedules (from residential areas to IT parks)
          morning_slots.sample(rand(2..4)).each do |departure_time|
            arrival_time = calculate_arrival_time(departure_time)

            schedules_batch << {
              bus_id: bus.id,
              date: date,
              departure_time: departure_time,
              arrival_time: arrival_time,
              start_point: start_points.sample,
              available_seats: bus.capacity,
              created_at: Time.current,
              updated_at: Time.current
            }

            # Insert in batches for performance
            next unless schedules_batch.size >= batch_size

            Schedule.insert_all(schedules_batch)
            total_schedules_created += schedules_batch.size
            schedules_batch.clear
          end

          # Evening drop schedules (from IT parks to residential areas)
          evening_slots.sample(rand(2..4)).each do |departure_time|
            arrival_time = calculate_arrival_time(departure_time)

            schedules_batch << {
              bus_id: bus.id,
              date: date,
              departure_time: departure_time,
              arrival_time: arrival_time,
              start_point: company_destination,
              available_seats: bus.capacity,
              created_at: Time.current,
              updated_at: Time.current
            }

            next unless schedules_batch.size >= batch_size

            Schedule.insert_all(schedules_batch)
            total_schedules_created += schedules_batch.size
            schedules_batch.clear
          end

          # Night shifts for some companies (30% chance)
          next unless rand(1..100) <= 30

          night_slots.sample(rand(1..2)).each do |departure_time|
            arrival_time = calculate_arrival_time(departure_time)

            schedules_batch << {
              bus_id: bus.id,
              date: date,
              departure_time: departure_time,
              arrival_time: arrival_time,
              start_point: start_points.sample,
              available_seats: bus.capacity,
              created_at: Time.current,
              updated_at: Time.current
            }

            next unless schedules_batch.size >= batch_size

            Schedule.insert_all(schedules_batch)
            total_schedules_created += schedules_batch.size
            schedules_batch.clear
          end
        end
      end
    end

    # Insert any remaining schedules
    if schedules_batch.any?
      Schedule.insert_all(schedules_batch)
      total_schedules_created += schedules_batch.size
    end

    puts "Created #{total_schedules_created} weekday schedules"
  end
rescue StandardError => e
  puts "XXX Error creating weekday schedules: #{e.message}"
  puts e.backtrace.first(5)
end

# Weekend schedules in separate transaction
puts 'Creating weekend schedules...'

begin
  Schedule.transaction do
    weekend_schedules_batch = []
    batch_size = 500

    weekend_companies = Company.includes(:buses).where(name: %w[Infosys Wipro TCS Accenture Cognizant])
    weekend_time_slots = ['09:00', '10:00', '17:00', '18:00']

    weekend_companies.each do |company|
      company_buses = company.buses
      next if company_buses.empty?

      puts "Creating weekend schedules for #{company.name}"

      # Pre-calculate company-specific destination
      company_destination = destinations.find { |d| d.include?(company.name.split.first) } || destinations.sample

      # Next two weekends
      [0, 1].each do |week_offset|
        saturday = Date.today.end_of_week - 1 + (week_offset * 7)
        sunday = saturday + 1

        [saturday, sunday].each do |weekend_date|
          company_buses.sample(rand(1..2)).each do |bus|
            weekend_time_slots.sample(rand(1..2)).each do |departure_time|
              arrival_time = calculate_arrival_time(departure_time)

              weekend_schedules_batch << {
                bus_id: bus.id,
                date: weekend_date,
                departure_time: departure_time,
                arrival_time: arrival_time,
                start_point: [start_points.sample, company_destination].sample,
                available_seats: bus.capacity,
                created_at: Time.current,
                updated_at: Time.current
              }

              if weekend_schedules_batch.size >= batch_size
                Schedule.insert_all(weekend_schedules_batch)
                weekend_schedules_batch.clear
              end
            end
          end
        end
      end
    end

    # Insert any remaining weekend schedules
    Schedule.insert_all(weekend_schedules_batch) if weekend_schedules_batch.any?

    puts "Completed creating schedules. Total: #{Schedule.count}"
  end
rescue StandardError => e
  puts "XXX Error creating weekend schedules: #{e.message}"
  puts e.backtrace.first(5)
end

puts 'Schedules creation completed successfully!'
