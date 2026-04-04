# frozen_string_literal: true

module BusService
  class Update < Base
    attr_reader :params, :current_user, :bus
    SUCCESS_KEY = 'bus.update.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        find_bus && update_bus && set_data && set_response
      end
      result || set_response
    end

    private

    def find_bus
      @bus = BusRepository.find_by_column(:uid, params[:id])
      return true if bus

      add_error('bus.not_found')
      false
    end

    def update_bus
      return true if bus.update(params.slice(:number, :capacity, :model, :company_id))

      add_error('bus.update.failure', message: bus.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::BusSerializer.new(bus.reload).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
