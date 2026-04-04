# frozen_string_literal: true

module ReservationService
  class Index < Base
    attr_accessor :reservations
    SUCCESS_KEY = 'reservation.index.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (fetch_reservations && set_data && set_response) || set_response
    end

    private

    def fetch_reservations
      scope = ReservationRepository.index(
        search: @params[:search],
        sort_by: @params[:sort_by],
        sort_order: @params[:sort_order]
      )
      result = paginate(scope, page: @params[:page], per_page: @params[:per_page])
      @reservations = result[:records]
      @meta = result[:meta]
      true
    end

    def set_data
      @data = V1::ReservationSerializer.new(reservations).serializable_hash
      @data[:meta] = @meta
      @message = translate(SUCCESS_KEY)
    end
  end
end
