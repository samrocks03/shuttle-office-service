# frozen_string_literal: true

module Api
  module V1
    class FareTablesController < ApplicationController
      include RoutingAdminAuthorization

      before_action { authorize! :read, FareTable }

      def index
        result = FareTableService::Index.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end

      def show
        result = FareTableService::Show.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end
    end
  end
end
