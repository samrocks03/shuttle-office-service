# frozen_string_literal: true

class Bus < ApplicationRecord
  has_many :schedules, dependent: :destroy
  belongs_to :company

  validates :number, :capacity, :model, presence: true
  validates :number, uniqueness: true

  before_validation :normalize_model

  def as_json(options: {})
    super(only: %i[id number capacity model company_id])
  end

  private

  def normalize_model
    self.model = model&.downcase&.titleize
    self.number = number&.downcase&.titleize
  end
end
