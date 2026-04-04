# frozen_string_literal: true

module BusService
  class Index < Base
    attr_accessor :buses
    SUCCESS_KEY = 'bus.index.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (fetch_buses && set_data && set_response) || set_response
    end

    private

    def fetch_buses
      scope = BusRepository.index(
        search: @params[:search],
        sort_by: @params[:sort_by],
        sort_order: @params[:sort_order]
      )
      result = paginate(scope, page: @params[:page], per_page: @params[:per_page])
      @buses = result[:records]
      @meta = result[:meta]
      true
    end

    def set_data
      @data = V1::BusSerializer.new(buses).serializable_hash
      @data[:meta] = @meta
      @message = translate(SUCCESS_KEY)
    end
  end
end
