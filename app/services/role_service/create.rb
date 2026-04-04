# frozen_string_literal: true

module RoleService
  class Create < Base
    attr_reader :params, :current_user, :role
    SUCCESS_KEY = 'role.create.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        create_role && set_data && set_response
      end
      result || set_response
    end

    private

    def create_role
      @role = Role.new(name: params[:name], role_type: params[:role_type])
      return true if role.save

      add_error('role.create.failure', message: role.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::RoleSerializer.new(role).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
