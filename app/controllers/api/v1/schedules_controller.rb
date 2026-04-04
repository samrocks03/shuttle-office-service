# frozen_string_literal: true

module Api
  module V1
    class SchedulesController < ApplicationController
      def index
        result = ScheduleService::Index.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def show
        result = ScheduleService::Show.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :not_found
      end

      def create
        result = ScheduleService::Create.new(schedule_params, current_user_params).call
        render json: result.to_h, status: result.success ? :created : :unprocessable_entity
      end

      def update
        result = ScheduleService::Update.new(schedule_params.merge(id: params[:id]), current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      def destroy
        result = ScheduleService::Destroy.new(params, current_user_params).call
        render json: result.to_h, status: result.success ? :ok : :unprocessable_entity
      end

      private

      def schedule_params
        params.require(:schedule).permit(:start_point, :arrival_time, :departure_time, :date, :bus_id)
      end
    end
  end
end
