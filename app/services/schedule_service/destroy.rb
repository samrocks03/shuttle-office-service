# frozen_string_literal: true

module ScheduleService
  class Destroy < Base
    attr_reader :params, :current_user, :schedule
    SUCCESS_KEY = 'schedule.destroy.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_schedule && destroy_schedule && set_success) || set_response
    end

    private

    def find_schedule
      @schedule = ScheduleRepository.find_by_column(:uid, params[:id])
      return true if schedule

      add_error('schedule.not_found')
      false
    end

    def destroy_schedule
      return true if schedule.destroy

      add_error('schedule.destroy.failure')
      false
    end

    def set_success
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
