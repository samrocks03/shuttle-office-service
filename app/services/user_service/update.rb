# frozen_string_literal: true

module UserService
  class Update < Base
    attr_reader :params, :current_user, :user
    SUCCESS_KEY = 'user.update.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        find_user && update_user && set_data && set_response
      end
      result || set_response
    end

    private

    def find_user
      @user = UserRepository.find_by_column(:uid, params[:id])
      return true if user

      add_error('user.not_found')
      false
    end

    def update_user
      return true if user.update(params.slice(:first_name, :last_name, :phone_number, :email, :company_id))

      add_error('user.update.failure', message: user.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::UserSerializer.new(user.reload).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
