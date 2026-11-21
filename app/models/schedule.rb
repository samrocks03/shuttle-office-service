# frozen_string_literal: true

class Schedule < ApplicationRecord
  include UidGenerator

  belongs_to :bus, inverse_of: :schedules
  belongs_to :from_stop, class_name: 'Stop', optional: true
  belongs_to :to_stop, class_name: 'Stop', optional: true
  has_many :reservations, dependent: :destroy, inverse_of: :schedule

  validates :start_point, :arrival_time, :departure_time, presence: true

  validate :arr_dept_validation
  validate :unique_schedule_within_duration, on: :create

  after_initialize :set_default_available_seats

  def decrement_available_seat!
    rows = self.class.where(id: id).where('available_seats > 0')
                .update_all('available_seats = available_seats - 1')
    reload
    rows.positive?
  end

  def increment_available_seat!
    rows = self.class.joins(:bus).where(id: id)
                .where('schedules.available_seats < buses.capacity')
                .update_all('available_seats = available_seats + 1')
    reload
    rows.positive?
  end

  def city
    bus&.company&.city
  end

  def stop_distance
    return unless from_stop_id && to_stop_id

    StopDistance.between(from_stop, to_stop)
  end

  private

  def arr_dept_validation
    return unless arrival_time && departure_time

    errors.add(:arrival_time, message: 'must be greater than departure time') if arrival_time <= departure_time
  end

  def set_default_available_seats
    return unless available_seats.nil? && bus

    self.available_seats = bus.capacity
  end

  def unique_schedule_within_duration
    existing_schedules = Schedule.where(bus_id: bus_id, date: date)
    overlapping_schedules = existing_schedules.select do |existing_schedule|
      (existing_schedule.departure_time..existing_schedule.arrival_time).cover?(departure_time) ||
        (departure_time..arrival_time).cover?(existing_schedule.departure_time)
    end

    return unless overlapping_schedules.any?

    errors.add(:overlapping_schedules, 'with existing schedule for the same bus on the same day')
  end
end
