# frozen_string_literal: true

module UserService
  class Destroy < Base
    attr_reader :params, :current_user, :user
    SUCCESS_KEY = 'user.destroy.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_user && destroy_user && set_success) || set_response
    end

    private

    def find_user
      @user = UserRepository.find_by_column(:uid, params[:id])
      return true if user

      add_error('user.not_found')
      false
    end

    def destroy_user
      return true if user.destroy

      add_error('user.destroy.failure')
      false
    end

    def set_success
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
