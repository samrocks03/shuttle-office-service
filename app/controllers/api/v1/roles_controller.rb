# frozen_string_literal: true

module Api
  module V1
    class RolesController < ApplicationController
      skip_before_action :authenticate, only: %i[index]

      def index
        result = RoleService::Index.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def show
        result = RoleService::Show.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end

      def create
        result = RoleService::Create.new(role_params, current_user_params).call
        render json: result.to_h, status: result.success ? :created : :unprocessable_entity
      end

      def update
        result = RoleService::Update.new(role_params.merge(id: params[:id]), current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def destroy
        result = RoleService::Destroy.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      private

      def role_params
        params.require(:role).permit(:name, :role_type)
      end
    end
  end
end
