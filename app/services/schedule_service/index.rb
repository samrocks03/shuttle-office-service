# frozen_string_literal: true

module ScheduleService
  class Index < Base
    attr_accessor :schedules

    SUCCESS_KEY = 'schedule.index.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (fetch_schedules && set_data && set_response) || set_response
    end

    private

    def fetch_schedules
      scope = ScheduleRepository.index(
        search: @params[:search],
        sort_by: @params[:sort_by],
        sort_order: @params[:sort_order],
        bus_id: @params[:bus_id]
      )
      result = paginate(scope, page: @params[:page], per_page: @params[:per_page])
      @schedules = result[:records]
      @meta = result[:meta]
      true
    end

    def set_data
      @data = V1::ScheduleSerializer.new(schedules).serializable_hash
      @data[:meta] = @meta
      @message = translate(SUCCESS_KEY)
    end
  end
end
