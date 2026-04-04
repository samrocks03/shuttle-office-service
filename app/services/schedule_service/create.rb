# frozen_string_literal: true

module ScheduleService
  class Create < Base
    attr_reader :params, :current_user, :schedule
    SUCCESS_KEY = 'schedule.create.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        validate_date && create_schedule && set_data && set_response
      end
      result || set_response
    end

    private

    def validate_date
      date = Date.parse(params[:date].to_s) rescue nil
      return true if date && date >= Date.today

      add_error('schedule.date_in_past')
      false
    end

    def create_schedule
      @schedule = Schedule.new(
        start_point: params[:start_point],
        arrival_time: params[:arrival_time],
        departure_time: params[:departure_time],
        date: params[:date],
        bus_id: params[:bus_id]
      )
      return true if schedule.save

      add_error('schedule.create.failure', message: schedule.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::ScheduleSerializer.new(schedule).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
