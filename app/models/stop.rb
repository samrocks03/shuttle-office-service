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

  after_commit :enqueue_distance_computation, if: :distance_inputs_changed?

  private

  def distance_inputs_changed?
    saved_change_to_id? || saved_change_to_latitude? || saved_change_to_longitude? ||
      saved_change_to_city_id? || saved_change_to_kind? || (saved_change_to_active? && active?)
  end

  def enqueue_distance_computation
    ComputeCityDistancesJob.perform_later(city_id)
  end
end
