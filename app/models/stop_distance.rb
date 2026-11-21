# frozen_string_literal: true

class StopDistance < ApplicationRecord
  include UidGenerator

  belongs_to :from_stop, class_name: 'Stop'
  belongs_to :to_stop, class_name: 'Stop'
  belongs_to :overridden_by, class_name: 'User', optional: true, inverse_of: :overridden_stop_distances

  # An admin override can be any positive distance up to this many kilometres.
  MAX_OVERRIDE_KM = 500
  MAX_REASON_LENGTH = 255

  validates :to_stop_id, uniqueness: { scope: :from_stop_id }
  validates :override_km, numericality: { greater_than: 0, less_than_or_equal_to: MAX_OVERRIDE_KM }, allow_nil: true
  validates :override_reason, length: { maximum: MAX_REASON_LENGTH }

  def self.between(from_stop, to_stop)
    find_by(from_stop: from_stop, to_stop: to_stop)
  end

  def effective_km
    override_km || computed_km
  end
end
