# frozen_string_literal: true

class FareTable < ApplicationRecord
  include UidGenerator

  belongs_to :city, inverse_of: :fare_tables
  has_many :fare_slabs, -> { order(:up_to_km) }, dependent: :destroy, inverse_of: :fare_table

  validates :service_class, inclusion: { in: Bus::SERVICE_CLASSES }
  validates :currency, :policy, :effective_from, presence: true
  validates :step_km, numericality: { greater_than: 0 }, allow_nil: true
  validates :step_amount_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # A fare table is versioned: once a reservation has snapshotted it, it is never edited or removed.
  before_update :ensure_unused
  before_destroy :ensure_unused

  # The table in force on `date`: active, latest effective_from not after the date.
  # To change prices, add a new table with a later effective_from.
  def self.active_on(city, service_class, date)
    where(city: city, service_class: service_class, active: true)
      .where(effective_from: ..date)
      .order(effective_from: :desc)
      .first
  end

  private

  def ensure_unused
    return unless Reservation.exists?(fare_table_id: id)

    raise ActiveRecord::ReadOnlyRecord, 'fare table is used by a reservation; add a new table instead'
  end
end
