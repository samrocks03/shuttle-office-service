# frozen_string_literal: true

module Api
  module V1
    class CompaniesController < ApplicationController
      skip_before_action :authenticate, only: %i[index]

      def index
        result = CompanyService::Index.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def show
        result = CompanyService::Show.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end

      def create
        result = CompanyService::Create.new(company_params, current_user_params).call
        render json: result.to_h, status: result.success ? :created : :unprocessable_entity
      end

      def update
        result = CompanyService::Update.new(company_params.merge(id: params[:id]), current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def destroy
        result = CompanyService::Destroy.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      private

      def company_params
        params.require(:company).permit(:name, :location)
      end
    end
  end
end
