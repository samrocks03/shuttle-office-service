# frozen_string_literal: true

module UserService
  class Show < Base
    attr_reader :params, :current_user, :user
    SUCCESS_KEY = 'user.show.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_user && set_data && set_response) || set_response
    end

    private

    def find_user
      @user = UserRepository.find_by_column(:uid, params[:id])
      return true if user

      add_error('user.not_found')
      false
    end

    def set_data
      @data = V1::UserSerializer.new(user).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
