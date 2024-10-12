# frozen_string_literal: true

class RolesController < ApplicationController
  before_action :set_role, only: %i[show update destroy]

  load_and_authorize_resource
  # GET /roles
  # GET /roles.json
  def index
    @roles = Role.all
    render json: @roles
  end

  # GET /roles/1
  # GET /roles/1.json
  def show
    render json: @role
  end

  # POST /roles
  # POST /roles.json
  def create
    @role = Role.new(role_params)

    if @role.save
      render json: @role, status: :created, location: @role
    else
      render json: @role.errors.full_messages, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /roles/1
  # PATCH/PUT
  def update
    if @role.update(role_params)
      render json: @role
    else
      render json: @role.errors.full_messages, status: :unprocessable_entity
    end
  end

  def destroy
    @role.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_role
    @role = Role.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def role_params
    params.require(:role).permit(:name)
  end
end
