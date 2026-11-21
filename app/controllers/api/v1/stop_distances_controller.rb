# frozen_string_literal: true

module Api
  module V1
    class StopDistancesController < ApplicationController
      include RoutingAdminAuthorization

      before_action(only: :index) { authorize! :read, StopDistance }
      before_action(only: :update) { authorize! :update, StopDistance }

      def index
        result = StopDistanceService::Index.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end

      def update
        result = StopDistanceService::Update.new(override_params.merge(id: params[:id]), current_user_params).call
        render json: result.to_h, status: result.success ? :ok : failure_status(result)
      end

      private

      def failure_status(result)
        result.error_key == 'stop_distance.not_found' ? :not_found : :unprocessable_entity
      end

      # Read from the top level; `override_km: null` must stay a key so the service can tell a clear
      # from a request that does not mention the kilometres.
      def override_params
        params.permit(:override_km, :override_reason)
      end
    end
  end
end
