# frozen_string_literal: true

module CompanyService
  class Destroy < Base
    attr_reader :params, :current_user, :company
    SUCCESS_KEY = 'company.destroy.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      (find_company && destroy_company && set_success) || set_response
    end

    private

    def find_company
      @company = CompanyRepository.find_by_column(:uid, params[:id])
      return true if company

      add_error('company.not_found')
      false
    end

    def destroy_company
      return true if company.destroy

      add_error('company.destroy.failure')
      false
    end

    def set_success
      @message = translate(SUCCESS_KEY)
      set_response
    end
  end
end
