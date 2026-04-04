# frozen_string_literal: true

module CompanyService
  class Show < Base
    attr_reader :params, :current_user, :company
    SUCCESS_KEY = 'company.show.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_company && set_data && set_response) || set_response
    end

    private

    def find_company
      @company = CompanyRepository.find_by_column(:uid, params[:id])
      return true if company

      add_error('company.not_found')
      false
    end

    def set_data
      @data = V1::CompanySerializer.new(company).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
