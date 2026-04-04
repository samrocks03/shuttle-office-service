# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate, only: %i[login register]

      def login
        result = UserService::Login.new(login_params).call
        render json: result.to_h, status: result.success ? :accepted : :unauthorized
      end

      def register
        result = UserService::Register.new(register_params).call
        render json: result.to_h, status: result.success ? :created : :unprocessable_entity
      end

      private

      def login_params
        params.require(:user).permit(:email, :password)
      end

      def register_params
        params.require(:user).permit(:first_name, :last_name, :phone_number, :email, :password, :company_id, :role_id)
      end
    end
  end
end
