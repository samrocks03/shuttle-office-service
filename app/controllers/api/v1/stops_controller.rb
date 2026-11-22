# frozen_string_literal: true

module Api
  module V1
    class StopsController < ApplicationController
      include RoutingAdminAuthorization

      before_action { authorize! :read, Stop }
      before_action(only: :create) { authorize! :create, Stop }
      before_action(only: :update) { authorize! :update, Stop }
      before_action(only: :destroy) { authorize! :destroy, Stop }

      def index
        result = StopService::Index.new(city_params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : failure_status(result)
      end

      def show
        result = StopService::Show.new(city_params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end

      def create
        result = StopService::Create.new(stop_params.merge(city_uid: params[:city_id]), current_user_params).call
        render json: result.to_h, status: result.success ? :created : failure_status(result)
      end

      def update
        result = StopService::Update.new(stop_params.merge(city_uid: params[:city_id], id: params[:id]),
                                         current_user_params).call
        render json: result.to_h, status: result.success ? :ok : failure_status(result)
      end

      def destroy
        result = StopService::Destroy.new(city_params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : failure_status(result)
      end

      private

      # The nested route names the city `city_id`, but it holds the city's uid.
      def city_params
        params.to_unsafe_h.merge(city_uid: params[:city_id])
      end

      def failure_status(result)
        result.error_key.to_s.end_with?('not_found') ? :not_found : :unprocessable_entity
      end

      def stop_params
        params.require(:stop).permit(:name, :kind, :latitude, :longitude, :active, :osm_ref)
      end
    end
  end
end
