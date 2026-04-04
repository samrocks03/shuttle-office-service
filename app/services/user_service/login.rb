# frozen_string_literal: true

module UserService
  class Login < Base
    attr_reader :params, :user
    SUCCESS_KEY = 'authentication.errors.login.success.message'

    def initialize(params)
      super()
      @params = normalize_params(params)
    end

    def call
      (find_user && authenticate_user && set_data && set_response) || set_response
    end

    private

    def find_user
      @user = UserRepository.find_by_email(params[:email])
      return true if user

      add_error('authentication.errors.invalid_credentials')
      false
    end

    def authenticate_user
      return true if user.authenticate(params[:password])

      add_error('authentication.errors.invalid_credentials')
      false
    end

    def set_data
      token = encode_token(
        user_id: user.id,
        user_uid: user.uid,
        role_type: user.role&.role_type,
        company_id: user.company_id
      )
      @data = {
        data: {
          user: V1::UserSerializer.new(user).serializable_hash,
          token: token
        }
      }
      @message = translate(SUCCESS_KEY)
    end

    def encode_token(payload)
      JWT.encode(payload, Rails.application.credentials[:secret_key_base])
    end
  end
end
