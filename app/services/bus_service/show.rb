# frozen_string_literal: true

module BusService
  class Show < Base
    attr_reader :params, :current_user, :bus
    SUCCESS_KEY = 'bus.show.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_bus && set_data && set_response) || set_response
    end

    private

    def find_bus
      @bus = BusRepository.find_by_column(:uid, params[:id])
      return true if bus

      add_error('bus.not_found')
      false
    end

    def set_data
      @data = V1::BusSerializer.new(bus).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
