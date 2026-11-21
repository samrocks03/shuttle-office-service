# frozen_string_literal: true

class Bus < ApplicationRecord
  include UidGenerator

  SERVICE_CLASSES = %w[non_ac ac].freeze

  belongs_to :company, inverse_of: :buses
  has_many :schedules, dependent: :destroy, inverse_of: :bus

  validates :number, :capacity, :model, presence: true
  validates :number, uniqueness: true
  validates :service_class, inclusion: { in: SERVICE_CLASSES }

  before_validation :normalize_model

  private

  def normalize_model
    self.model = model&.downcase&.titleize
    self.number = number&.downcase&.titleize
  end
end
