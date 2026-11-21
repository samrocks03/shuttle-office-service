# frozen_string_literal: true

class City < ApplicationRecord
  include UidGenerator

  has_many :stops, dependent: :restrict_with_error, inverse_of: :city
  has_many :companies, dependent: :nullify, inverse_of: :city
  has_many :fare_tables, dependent: :restrict_with_error, inverse_of: :city

  validates :name, :country_code, :currency, :time_zone, :distance_provider, presence: true
end
