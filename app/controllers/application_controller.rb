# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :authenticate

  rescue_from CanCan::AccessDenied do |exception|
    render json: { success: false, errors: { base: [exception.message] } }, status: :forbidden
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: { success: false, errors: { base: [exception.message] } }, status: :not_found
  end

  rescue_from ActiveRecord::RecordNotUnique do |exception|
    field = exception.message[/Key \((.+?)\)/, 1] || 'record'
    render json: { success: false, errors: { base: ["#{field} already exists"] } }, status: :conflict
  end

  rescue_from ActiveRecord::StatementInvalid do |exception|
    status = exception.message.include?('PG::UndefinedColumn') ? :unprocessable_entity : :internal_server_error
    render json: { success: false, errors: { base: [exception.message] } }, status: status
  end

  private

  def authenticate
    @decode = decoded_token&.first
    @current_user = @decode ? User.find_by(id: @decode['user_id']) : nil

    return if @current_user

    render json: { success: false, errors: { base: [I18n.t('authentication.errors.unauthorized.detail')] } },
           status: :unauthorized
  end

  def current_user_params
    { user_id: @current_user&.id, user_uid: @current_user&.uid }
  end

  def encode_token(payload)
    JWT.encode(payload, Rails.application.credentials[:secret_key_base])
  end

  def decoded_token
    token = token_from_header || token_from_cookie
    return unless token

    JWT.decode(token, Rails.application.credentials[:secret_key_base])
  rescue JWT::DecodeError
    nil
  end

  def token_from_header
    header = request.headers['Authorization']
    header&.split(' ')&.last
  end

  def token_from_cookie
    cookies[:token]
  end
end
