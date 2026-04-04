# frozen_string_literal: true

module RoleService
  class Update < Base
    attr_reader :params, :current_user, :role
    SUCCESS_KEY = 'role.update.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        find_role && update_role && set_data && set_response
      end
      result || set_response
    end

    private

    def find_role
      @role = RoleRepository.find_by_column(:uid, params[:id])
      return true if role

      add_error('role.not_found')
      false
    end

    def update_role
      return true if role.update(params.slice(:name, :role_type))

      add_error('role.update.failure', message: role.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::RoleSerializer.new(role.reload).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
