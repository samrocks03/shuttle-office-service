# frozen_string_literal: true

class ComputeCityDistancesJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(city_id)
    Distances::ComputeForCity.new(City.find(city_id)).call
  end
end
