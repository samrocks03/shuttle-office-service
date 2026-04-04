# frozen_string_literal: true

module UserService
  class Register < Base
    attr_reader :params, :user
    SUCCESS_KEY = 'authentication.errors.register.success.message'

    def initialize(params)
      super()
      @params = normalize_params(params)
    end

    def call
      result = ActiveRecord::Base.transaction do
        create_user && set_data && set_response
      end
      result || set_response
    end

    private

    def create_user
      @user = User.new(
        first_name: params[:first_name],
        last_name: params[:last_name],
        phone_number: params[:phone_number]&.gsub(/\D/, ''),
        email: params[:email],
        password: params[:password],
        company_id: params[:company_id],
        role_id: params[:role_id] || Role.user_role&.id
      )
      return true if user.save

      add_error('user.create.failure', message: user.errors.full_messages.join(', '))
      false
    end

    def set_data
      token = encode_token(user_id: user.id, user_uid: user.uid)
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
