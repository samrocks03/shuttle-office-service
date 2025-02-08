# frozen_string_literal: true

class Schedule < ApplicationRecord
  belongs_to :bus
  has_many :reservations, dependent: :destroy

  validates :start_point, :arrival_time, :departure_time, presence: true

  validate :arr_dept_validation
  validate :unique_schedule_within_duration, on: :create

  after_initialize :set_default_available_seats

  def decrement_available_seat
    update(available_seats: available_seats - 1)
  end

  def increment_available_seat
    update(available_seats: available_seats + 1)
  end

  private

  def arr_dept_validation
    return unless arrival_time && departure_time

    errors.add(:arrival_time, message: 'must be greater than departure time') if arrival_time <= departure_time
  end

  def set_default_available_seats
    self.available_seats ||= bus.capacity if bus
  end

  def unique_schedule_within_duration
    existing_schedules = Schedule.where(bus_id:, date:)
    overlapping_schedules = existing_schedules.select do |existing_schedule|
      (existing_schedule.departure_time..existing_schedule.arrival_time).cover?(departure_time) ||
        (departure_time..arrival_time).cover?(existing_schedule.departure_time)
    end

    return unless overlapping_schedules.any?

    errors.add(:overlapping_schedules, 'with existing schedule for the same bus on the same day')
  end
end
