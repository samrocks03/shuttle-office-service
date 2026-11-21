# frozen_string_literal: true

# Shared by the routing admin services: finds the city a request is scoped to, by uid.
module CityLookup
  private

  def find_city(uid)
    @city = uid.present? ? City.find_by(uid: uid) : nil
    return true if @city

    add_error('city.not_found')
    false
  end
end
