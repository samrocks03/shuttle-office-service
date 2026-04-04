# frozen_string_literal: true

module RoleService
  class Index < Base
    attr_accessor :roles
    SUCCESS_KEY = 'role.index.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (fetch_roles && set_data && set_response) || set_response
    end

    private

    def fetch_roles
      scope = RoleRepository.index(
        search: @params[:search],
        sort_by: @params[:sort_by],
        sort_order: @params[:sort_order]
      )
      result = paginate(scope, page: @params[:page], per_page: @params[:per_page])
      @roles = result[:records]
      @meta = result[:meta]
      true
    end

    def set_data
      @data = V1::RoleSerializer.new(roles).serializable_hash
      @data[:meta] = @meta
      @message = translate(SUCCESS_KEY)
    end
  end
end
