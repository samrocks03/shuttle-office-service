# frozen_string_literal: true

module FareTableService
  class Index < Base
    include CityLookup

    SUCCESS_KEY = 'fare_table.index.success.message'
    MAX_ROWS = 200

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      return set_response unless find_city(@params[:city_uid])

      tables = @city.fare_tables.includes(:city, :fare_slabs)
                    .order(:service_class, effective_from: :desc).limit(MAX_ROWS)
      @data = V1::FareTableSerializer.new(tables).serializable_hash
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
