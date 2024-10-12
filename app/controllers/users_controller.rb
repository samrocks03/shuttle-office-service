# frozen_string_literal: true

class UsersController < ApplicationController
  skip_before_action :authorized, only: %i[create login]
  rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record
  before_action :set_user, only: %i[show update destroy]

  load_and_authorize_resource except: %i[login create]
  # check for except: :create, :login

  # GET /users
  def index
    # @users = User.all.order("#{params[:order_by]} #{params[:order_type]}")
    # # debugger
    # # @users = @users.where("users.first_name ILIKE ?", params[:search])
    # # debugger
    # @pagy, @users = pagy(@users,page: params[:page],items: params[:per_page])
    # # debugger

    @users = User.all

    # Searching based on params
    if params[:search].present?
      @users = @users.where("users.first_name ILIKE ? OR
                             users.last_name ILIKE ? OR
                             users.phone_number ILIKE? OR
                             users.email ILIKE ?",
                            "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    # Sorting based on asc/ desc if given
    if params[:order_by].present? && params[:order_type].present?
      order_clause = "#{params[:order_by]} #{params[:order_type]}"
      @users = @users.order(order_clause)
    end

    # Pagination with per_page
    if params[:per_page].present? && params[:page].present?
      @pagy, @users = pagy(@users, page: params[:page], items: params[:per_page])
    end

    render json: {
      data_body: @users.map(&method(:users_json)),
      meta_data: {
        current_page_number: @pagy&.items || @users.count,
        current_page: @pagy&.page || 1,
        total_count: @pagy&.count || @users.count
      }
    }, status: :ok
    # render json: @users, status: :ok
  end

  # GET /users/1
  def show
    # debugger
    # @user = User.find(params[:id])
    render json: @user
  end

  # POST /login
  def login
    @user = User.find_by!(email: login_params[:email])

    # byebug
    if @user.authenticate(login_params[:password])
      token = encode_token({ user_id: @user.id })
      render json: {
        user: UserSerializer.new(@user),
        token:
      }, status: :accepted
    else
      render json: {
        error: 'Invalid password'
      }, status: :unauthorized
    end
  end

  # POST /users
  def create
    # byebug
    @user = User.new(user_params)
    @token = encode_token(user_id: @user.id)
    # byebug
    if @user.save
      render json: {
        user: UserSerializer.new(@user),
        token: @token
      }, status: :created
    else
      render json: @user.errors.full_messages, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/1
  # PATCH/PUT
  def update
    if @user.update(user_params)
      render json: @user
    else
      render json: @user.errors.full_messages, status: :unprocessable_entity
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy
    render json: { message: 'User Successfully deleted' }, status: :ok
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    # debugger
    @user = User.find_by(id: params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    # byebug
    params.require(:user).permit(:first_name, :last_name, :phone_number, :email, :company_id, :password)
  end

  def handle_invalid_errors(e)
    render json: { errors: e.record.errors.full_messages }
  end

  def login_params
    params.require(:user).permit(:email, :password)
  end

  def users_json(user)
    {
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: user.phone_number,
      email: user.email,
      role_id: user.role_id
    }
  end
end
