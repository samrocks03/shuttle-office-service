# frozen_string_literal: true

class Reservation < ApplicationRecord
  include UidGenerator

  belongs_to :user, inverse_of: :reservations
  belongs_to :schedule, inverse_of: :reservations

  validates :schedule_id, :user_id, presence: true
  validates :schedule_id, uniqueness: { scope: :user_id, message: 'is already booked' }
end
