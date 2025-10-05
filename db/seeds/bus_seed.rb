# frozen_string_literal: true

puts "Creating buses..."

bus_models = [
  'Tata Starbus Prime LP910/52G',
  'Tata Starbus City',
  'Tata Magic Express',
  'Ashok Leyland 12M FE Staff',
  'Ashok Leyland Cheetah Staff',
  'Ashok Leyland Mitr Staff',
  'Ashok Leyland Viking Staff',
  'Mahindra Cruzio Grande',
  'SML Isuzu S7 Staff Bus',
  'SML Isuzu Executive LX',
  'Eicher Skyline 2075 H',
  'Eicher Pro 3012',
  'Eicher 6016 M LPO',
  'Force Traveller 3700WB',
  'Force Urbania',
  'Swaraj Mazda Staff Bus',
  'Bharat Benz Staff Bus',
  'Volvo 9400',
  'Scania Intercity 12M',
  'Tempo Traveller Mini Staff',
  'Himalaya Eicher Staff',
  'Tata LPO 1613',
  'Ashok Leyland JanBus',
  'Mahindra Supro Van',
  'Force Motors Cruiser',
  'Eicher Starline',
  'Volvo 8400',
  'Scania Metrolink',
  'Mercedes-Benz Tourismo',
  'MAN Lion\'s Coach',
  'Tata Marcopolo',
  'Ashok Leyland Oyster',
  'Mahindra T32',
  'SML Isuzu Supreme',
  'BharatBenz 1215R',
  'Eicher 20.16 XP',
  'Force Traveller 26',
  'Tata Winger',
  'Ashok Leyland 1613',
  'Mahindra Alfa Plus',
  'SML Isuzu Starbus'

]

total_buses_created = 0

Company.all.each do |company|
  puts "Creating buses for #{company.name}..."

  rand(6..8).times do |i|
    bus = Bus.find_or_create_by!(
      number: "#{company.name[0..3].upcase}#{100 + i}",
      capacity: [25, 30, 35, 40, 45, 50, 55].sample,
      model: bus_models.sample,
      company: company
    )

    total_buses_created += 1
    puts "--- Created bus #{bus.number} for #{company.name} (capacity: #{bus.capacity})"
  rescue StandardError => e
    puts "XXX Failed to create bus for #{company.name}: #{e.message}"
  end
end

puts "Bus creation completed! Total buses created: #{total_buses_created}"
