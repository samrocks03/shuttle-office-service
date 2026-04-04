# frozen_string_literal: true

module Api
  module V1
    class UsersController < ApplicationController
      def index
        result = UserService::Index.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def show
        result = UserService::Show.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end

      def create
        result = UserService::Create.new(user_params, current_user_params).call
        render json: result.to_h, status: result.success ? :created : :unprocessable_entity
      end

      def update
        result = UserService::Update.new(user_params.merge(id: params[:id]), current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def destroy
        result = UserService::Destroy.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      private

      def user_params
        params.require(:user).permit(:first_name, :last_name, :phone_number, :email, :password, :company_id, :role_id)
      end
    end
  end
end
