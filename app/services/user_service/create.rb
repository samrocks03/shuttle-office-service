# frozen_string_literal: true

module UserService
  class Create < Base
    attr_reader :params, :current_user, :user
    SUCCESS_KEY = 'user.create.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
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
        phone_number: params[:phone_number],
        email: params[:email],
        password: params[:password],
        company_id: params[:company_id],
        role_id: params[:role_id]
      )
      return true if user.save

      add_error('user.create.failure', message: user.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::UserSerializer.new(user).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
