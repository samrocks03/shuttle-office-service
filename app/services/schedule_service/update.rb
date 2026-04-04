# frozen_string_literal: true

module ScheduleService
  class Update < Base
    attr_reader :params, :current_user, :schedule
    SUCCESS_KEY = 'schedule.update.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        find_schedule && update_schedule && set_data && set_response
      end
      result || set_response
    end

    private

    def find_schedule
      @schedule = ScheduleRepository.find_by_column(:uid, params[:id])
      return true if schedule

      add_error('schedule.not_found')
      false
    end

    def update_schedule
      return true if schedule.update(params.slice(:start_point, :arrival_time, :departure_time, :date, :bus_id))

      add_error('schedule.update.failure', message: schedule.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::ScheduleSerializer.new(schedule.reload).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
