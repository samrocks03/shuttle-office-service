# frozen_string_literal: true

class Company < ApplicationRecord
  include UidGenerator

  belongs_to :city, optional: true, inverse_of: :companies
  has_many :stops, dependent: :restrict_with_error, inverse_of: :company
  has_many :users, dependent: :destroy, inverse_of: :company
  has_many :buses, dependent: :destroy, inverse_of: :company

  validates :name, :location, presence: true
  validates :name, uniqueness: true

  before_validation :normalise

  private

  def normalise
    self.name = name&.downcase&.titleize
    self.location = location&.downcase&.titleize
  end
end
