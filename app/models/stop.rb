# frozen_string_literal: true

class Stop < ApplicationRecord
  include UidGenerator

  KINDS = %w[pickup office].freeze

  belongs_to :city, inverse_of: :stops
  belongs_to :company, optional: true, inverse_of: :stops

  validates :name, :latitude, :longitude, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :pickups, -> { where(kind: 'pickup') }
  scope :offices, -> { where(kind: 'office') }
  scope :active, -> { where(active: true) }
end
