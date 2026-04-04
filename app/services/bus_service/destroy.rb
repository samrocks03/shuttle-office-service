# frozen_string_literal: true

module BusService
  class Destroy < Base
    attr_reader :params, :current_user, :bus
    SUCCESS_KEY = 'bus.destroy.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_bus && destroy_bus && set_success) || set_response
    end

    private

    def find_bus
      @bus = BusRepository.find_by_column(:uid, params[:id])
      return true if bus

      add_error('bus.not_found')
      false
    end

    def destroy_bus
      return true if bus.destroy

      add_error('bus.destroy.failure')
      false
    end

    def set_success
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
