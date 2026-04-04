# frozen_string_literal: true

module ReservationService
  class Show < Base
    attr_reader :params, :current_user, :reservation
    SUCCESS_KEY = 'reservation.show.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_reservation && set_data && set_response) || set_response
    end

    private

    def find_reservation
      @reservation = ReservationRepository.find_by_column(:uid, params[:id])
      return true if reservation

      add_error('reservation.not_found')
      false
    end

    def set_data
      @data = V1::ReservationSerializer.new(reservation).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
