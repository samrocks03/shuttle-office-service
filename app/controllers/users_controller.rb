# frozen_string_literal: true

class UsersController < ApplicationController
  include Paginatable
  include Searchable

  SEARCH_FIELDS = %w[users.first_name users.last_name users.phone_number users.email].freeze
  self.paginatable_options = { default_per_page: 10, max_per_page: 50 }

  skip_before_action :authorized, only: %i[create login]
  rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record
  before_action :set_user, only: %i[show update destroy]

  load_and_authorize_resource except: %i[login create]

  def index
    users = User.includes(:role, :company).all
    users = apply_search(users, SEARCH_FIELDS, params[:search])

    paginated_users = paginate(users)

    render json: {
      data: ActiveModelSerializers::SerializableResource.new(
        paginated_users,
        each_serializer: CompanySerializer
      ).serializable_hash,
      meta: pagination_meta
    }
  end

  def show
    render json: UserSerializer.new(@user)
  end

  # POST /login
  def login
    @user = User.find_by!(email: login_params[:email])

    if @user.authenticate(login_params[:password])
      token = encode_token({ user_id: @user.id })
      render json: {
        user: UserSerializer.new(@user),
        token:
      }, status: :accepted
    else
      render json: {
        error: {
          message: 'Invalid credentials',
          details: ['Email or password is incorrect']
        }
      }, status: :unauthorized
    end
  end

  # POST /users
  def create
    @user = User.new(user_params)

    if @user.save
      @token = encode_token(user_id: @user.id)

      render json: {
        user: UserSerializer.new(@user),
        token: @token
      }, status: :created
    else
      render json: @user.errors.full_messages, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/1
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
    @user = User.find_by(id: params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    params.require(:user).permit(:first_name, :last_name, :phone_number, :email, :company_id, :password)
  end

  def handle_invalid_errors(e)
    render json: { errors: e.record.errors.full_messages }
  end

  def login_params
    params.require(:user).permit(:email, :password)
  end

  def pagination_custom_meta
    {
      filtered_count: @users.count,
      timestamp: Time.current.iso8601
    }
  end
end
