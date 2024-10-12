# frozen_string_literal: true

class Company < ApplicationRecord
  # dependent is set to destroy, since, if i delete a company, then all has_many associations, set with it,must also get deleted

  has_many :users, dependent: :destroy
  has_many :buses, dependent: :destroy

  # has_one :schedule, dependent: :destroy

  validates :name, :location, presence: true
  validates :name, uniqueness: true

  before_validation :normalise

  def normalise
    self.name = name&.downcase&.titleize
    self.location = location&.downcase&.titleize
  end
end
