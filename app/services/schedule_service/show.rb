# frozen_string_literal: true

module ScheduleService
  class Show < Base
    attr_reader :params, :current_user, :schedule
    SUCCESS_KEY = 'schedule.show.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_schedule && set_data && set_response) || set_response
    end

    private

    def find_schedule
      @schedule = ScheduleRepository.find_by_column(:uid, params[:id])
      return true if schedule

      add_error('schedule.not_found')
      false
    end

    def set_data
      @data = V1::ScheduleSerializer.new(schedule).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
