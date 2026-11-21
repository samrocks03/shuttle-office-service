# frozen_string_literal: true

module FareTableService
  class Show < Base
    SUCCESS_KEY = 'fare_table.show.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      table = FareTable.includes(:city, :fare_slabs).find_by(uid: @params[:id])
      unless table
        add_error('fare_table.not_found')
        return set_response
      end

      @data = V1::FareTableSerializer.new(table).serializable_hash
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
