# frozen_string_literal: true

module BusService
  class Create < Base
    attr_reader :params, :current_user, :bus
    SUCCESS_KEY = 'bus.create.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        create_bus && set_data && set_response
      end
      result || set_response
    end

    private

    def create_bus
      @bus = Bus.new(
        number: params[:number],
        capacity: params[:capacity],
        model: params[:model],
        company_id: params[:company_id]
      )
      return true if bus.save

      add_error('bus.create.failure', message: bus.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::BusSerializer.new(bus).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
