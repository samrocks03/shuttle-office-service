# frozen_string_literal: true

module Api
  module V1
    class CitiesController < ApplicationController
      include RoutingAdminAuthorization

      before_action { authorize! :read, City }

      def index
        result = CityService::Index.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def show
        result = CityService::Show.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end
    end
  end
end
