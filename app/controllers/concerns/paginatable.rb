# frozen_string_literal: true

module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  included do
    class_attribute :paginatable_options, default: {}

    before_action :set_pagination_params, only: [:index]
    rescue_from Pagy::OverflowError, with: :handle_page_overflow
  end

  class_methods do
    def paginatable_options=(options)
      self.paginatable_options = options
    end
  end

  def paginate(collection)
    options = self.class.paginatable_options

    @pagy, paginated_collection = pagy(
      collection,
      page: params[:page] || options[:default_page] || DEFAULT_PAGE,
      items: calculate_per_page(options)
    )
    paginated_collection
  end

  def pagination_meta
    return {} unless @pagy

    meta = {
      current_page: @pagy.page,
      next_page: @pagy.next,
      prev_page: @pagy.prev,
      total_count: @pagy.count,
      total_pages: @pagy.pages,
      per_page: @pagy.items
    }

    # Add custom metadata if defined in controller
    meta.merge!(pagination_custom_meta) if respond_to?(:pagination_custom_meta, true)

    meta
  end

  private

  def calculate_per_page(options)
    per_page = params[:per_page] || options[:default_per_page] || DEFAULT_PER_PAGE
    max_per_page = options[:max_per_page] || MAX_PER_PAGE
    [per_page.to_i, max_per_page].min
  end

  def set_pagination_params # rubocop:disable Metrics/AbcSize
    params[:page] = params[:page].to_i if params[:page].present?
    params[:per_page] = params[:per_page].to_i if params[:per_page].present?

    # Ensure page is at least 1
    params[:page] = DEFAULT_PAGE if params[:page].present? && params[:page] < 1
  end

  def handle_page_overflow
    render json: {
      error: "Page #{params[:page]} is out of range. Total pages: #{@pagy&.pages || 1}"
    }, status: :bad_request
  end
end
