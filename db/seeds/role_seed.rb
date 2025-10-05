# frozen_string_literal: true

puts 'Creating roles...'

roles = [
  { name: 'Admin', role_type: :admin },
  { name: 'User', role_type: :user },
  { name: 'Guest', role_type: :guest }
]

roles.each do |role_attrs|
  role = Role.find_or_create_by!(name: role_attrs[:name]) do |r|
    r.role_type = role_attrs[:role_type]
  end
  puts "Created role: #{role.name} (#{role.role_type})"
end

puts 'Roles creation completed!'
