# frozen_string_literal: true

module CompanyService
  class Create < Base
    attr_reader :params, :current_user, :company
    SUCCESS_KEY = 'company.create.success.message'

    def initialize(params, current_user)
      super()
      @params = normalize_params(params)
      @current_user = current_user
    end

    def call
      result = ActiveRecord::Base.transaction do
        create_company && set_data && set_response
      end
      result || set_response
    end

    private

    def create_company
      @company = Company.new(name: params[:name], location: params[:location])
      return true if company.save

      add_error('company.create.failure', message: company.errors.full_messages.join(', '))
      false
    end

    def set_data
      @data = V1::CompanySerializer.new(company).serializable_hash
      @message = translate(SUCCESS_KEY)
    end
  end
end
