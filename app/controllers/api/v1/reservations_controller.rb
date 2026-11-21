# frozen_string_literal: true

module Api
  module V1
    class ReservationsController < ApplicationController
      def index
        result = ReservationService::Index.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def show
        result = ReservationService::Show.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end

      def create
        result = ReservationService::Create.new(reservation_params, current_user_params).call
        render json: result.to_h, status: result.success ? :created : create_failure_status(result)
      end

      def destroy
        result = ReservationService::Destroy.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : destroy_failure_status(result)
      end

      private

      def create_failure_status(result)
        result.error_key == 'reservation.guest_forbidden' ? :forbidden : :unprocessable_entity
      end

      def destroy_failure_status(result)
        result.error_key == 'reservation.not_found' ? :not_found : :unprocessable_entity
      end

      def reservation_params
        params.require(:reservation).permit(:user_id, :schedule_id)
      end
    end
  end
end
