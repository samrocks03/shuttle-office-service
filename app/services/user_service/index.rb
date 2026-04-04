# frozen_string_literal: true

module UserService
  class Index < Base
    attr_accessor :users
    SUCCESS_KEY = 'user.index.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (fetch_users && set_data && set_response) || set_response
    end

    private

    def fetch_users
      scope = UserRepository.index(
        search: @params[:search],
        sort_by: @params[:sort_by],
        sort_order: @params[:sort_order]
      )
      result = paginate(scope, page: @params[:page], per_page: @params[:per_page])
      @users = result[:records]
      @meta = result[:meta]
      true
    end

    def set_data
      @data = V1::UserSerializer.new(users).serializable_hash
      @data[:meta] = @meta
      @message = translate(SUCCESS_KEY)
    end
  end
end
