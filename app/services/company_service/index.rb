# frozen_string_literal: true

module CompanyService
  class Index < Base
    attr_accessor :companies

    SUCCESS_KEY = 'company.index.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (fetch_companies && set_data && set_response) || set_response
    end

    private

    def fetch_companies
      scope = CompanyRepository.index(
        search: @params[:search],
        sort_by: @params[:sort_by],
        sort_order: @params[:sort_order]
      )
      result = paginate(scope, page: @params[:page], per_page: @params[:per_page])
      @companies = result[:records]
      @meta = result[:meta]
      true
    end

    def set_data
      @data = V1::CompanySerializer.new(companies).serializable_hash
      @data[:meta] = @meta
      @message = translate(SUCCESS_KEY)
    end
  end
end
