# frozen_string_literal: true

class CompaniesController < ApplicationController
  skip_before_action :authorized, only: %i[show index]
  before_action :set_company, only: %i[show update destroy]

  load_and_authorize_resource
  # GET /companies
  def index
    @companies = Company.all

    if params[:search].present?
      @companies = @companies.where("
          companies.name ILIKE ? OR
          companies.location ILIKE ?
        ",
                                    "%#{params[:search]}%", "%#{params[:search]}%")
    end

    if params[:order_by].present? && params[:order_type].present?
      order_clause = "#{params[:order_by]} #{params[:order_type]}"
      @companies = @companies.order(order_clause)
    end

    # Pagination with per_page
    if params[:per_page].present? && params[:page].present?
      @pagy, @companies = pagy(@companies, page: params[:page], items: params[:per_page])
    end

    # @companies = Company.all.where("users.name ILIKE ?", params[:search])
    # debugger
    # @companies = Company.all.order("#{params[:order_by]} #{params[:order_type]}")
    # @pagy, @companies = pagy(@companies,page: params[:page],items: params[:per_page])

    # @companies = Company.all
    render json: {
      respBody: @companies.map(&method(:companies_json)),
      metaData: {
        current_page_number: @pagy&.items || @companies.count,
        current_page: @pagy&.page || 1,
        total_count: @pagy&.count || @companies.count
      }
    }, status: :ok
  end

  # GET /companies/1
  def show
    render json: companies_json(@company), status: :ok
  end

  # POST /companies
  def create
    @company = Company.new(company_params)

    if @company.save
      render json: companies_json(@company), status: :created, location: @company
    else
      render json: @company.errors.full_messages, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /companies/1
  # PATCH/PUT
  def update
    if @company.update(company_params)
      render json: companies_json(@company)
    else
      render json: @company.errors.full_messages, status: :unprocessable_entity
    end
  end

  def destroy
    @company.destroy
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_company
    @company = Company.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def company_params
    params.require(:company).permit(:name, :location)
  end

  # GET /companies/json
  def companies_json(company)
    {
      id: company.id,
      name: company.name,
      location: company.location
    }
  end
end
