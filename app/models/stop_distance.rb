# frozen_string_literal: true

class StopDistance < ApplicationRecord
  include UidGenerator

  belongs_to :from_stop, class_name: 'Stop'
  belongs_to :to_stop, class_name: 'Stop'
  belongs_to :overridden_by, class_name: 'User', optional: true, inverse_of: :overridden_stop_distances

  validates :to_stop_id, uniqueness: { scope: :from_stop_id }

  def self.between(from_stop, to_stop)
    find_by(from_stop: from_stop, to_stop: to_stop)
  end

  def effective_km
    override_km || computed_km
  end
end
