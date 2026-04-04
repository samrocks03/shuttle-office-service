# frozen_string_literal: true

module RoleService
  class Show < Base
    attr_reader :params, :current_user, :role
    SUCCESS_KEY = 'role.show.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_role && set_data && set_response) || set_response
    end

    private

    def find_role
      @role = RoleRepository.find_by_column(:uid, params[:id])
      return true if role

      add_error('role.not_found')
      false
    end

    def set_data
      @data = V1::RoleSerializer.new(role).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
