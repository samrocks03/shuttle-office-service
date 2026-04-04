# frozen_string_literal: true

module ReservationService
  class Destroy < Base
    attr_reader :params, :current_user, :reservation
    SUCCESS_KEY = 'reservation.destroy.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        find_reservation && lock_schedule && destroy_reservation && increment_seats && set_success
      end
      result || set_response
    end

    private

    def find_reservation
      @reservation = ReservationRepository.find_by_column(:uid, params[:id])
      return true if reservation

      add_error('reservation.not_found')
      false
    end

    def lock_schedule
      @schedule = Schedule.lock.find_by(id: reservation.schedule_id)
      return true if @schedule

      add_error('schedule.not_found')
      false
    end

    def destroy_reservation
      return true if reservation.destroy

      add_error('reservation.destroy.failure')
      false
    end

    def increment_seats
      @schedule.increment_available_seat!
      true
    end

    def set_success
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
