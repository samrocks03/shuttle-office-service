# frozen_string_literal: true

module CompanyService
  class Update < Base
    attr_reader :params, :current_user, :company
    SUCCESS_KEY = 'company.update.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        find_company && update_company && set_data && set_response
      end
      result || set_response
    end

    private

    def find_company
      @company = CompanyRepository.find_by_column(:uid, params[:id])
      return true if company

      add_error('company.not_found')
      false
    end

    def update_company
      return true if company.update(params.slice(:name, :location))

      add_error('company.update.failure', message: company.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::CompanySerializer.new(company.reload).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
