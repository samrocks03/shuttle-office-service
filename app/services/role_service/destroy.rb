# frozen_string_literal: true

module RoleService
  class Destroy < Base
    attr_reader :params, :current_user, :role
    SUCCESS_KEY = 'role.destroy.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_role && destroy_role && set_success) || set_response
    end

    private

    def find_role
      @role = RoleRepository.find_by_column(:uid, params[:id])
      return true if role

      add_error('role.not_found')
      false
    end

    def destroy_role
      return true if role.destroy

      add_error('role.destroy.failure')
      false
    end

    def set_success
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
