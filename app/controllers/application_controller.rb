# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Pagy::Backend
  before_action :authorized
  # rescue_from ActiveRecord::RecordNotFound do |excption|
  #   render json: { error: excption.message, status: 'record not found'}
  # end
  # load_and_authorize_resource

  rescue_from CanCan::AccessDenied do |exception|
    render json: { warning: exception.message, status: 'authorization failed' }
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: { warning: exception.message }, status: :not_found
  end

  rescue_from ActiveRecord::StatementInvalid do |exception|
    if exception.message.include?('PG::UndefinedColumn')
      render json: { warning: exception.message }, status: :unprocessable_entity
    else
      # Handle other ActiveRecord::StatementInvalid errors
      render json: { warning: "Database error occurred: #{exception.message}" }, status: :internal_server_error
    end
  end

  private

  def encode_token(payload)
    JWT.encode(payload, Rails.application.credentials[:secret_key_base])

    # This method takes a payload and returns a JWT token.
    # The payload is a hash that contains the user's id.
    # The JWT token is generated using the JWT.encode method,
    # which takes the payload and the secret key base as arguments.
  end

  def decoded_token
    header = request.headers['Authorization']
    return unless header

    token = header.split(' ').last
    begin
      JWT.decode(token, Rails.application.credentials[:secret_key_base])
    rescue JWT::DecodeError
      nil
    end
  end

  def current_user
    # if the token is decoded, it'll find the user by user_id
    # It will provide the user, which is currently logged in
    return unless decoded_token

    user_id = decoded_token[0]['user_id']
    User.find_by(id: user_id)
  end

  def authorized
    return unless current_user.nil?

    render json: { message: 'Please log in' }, status: :unauthorized
  end
end
