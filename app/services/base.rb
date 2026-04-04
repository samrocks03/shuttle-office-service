# frozen_string_literal: true

class Base
  include ActiveModel::Validations
  include Pagy::Backend

  attr_accessor :data, :message, :key

  EXCEPTION_KEY = 'exception.errors'

  def initialize
    @errors = ActiveModel::Errors.new(self)
    @data = {}
    @message = ''
    @key = ''
  end

  def errors
    @errors
  end

  def add_error(error_key, params = {})
    @key = error_key
    errors.add(:base, translate("#{error_key}.detail", **params))
    false
  end

  def set_response
    return OpenStruct.new(success: false, **serialize_errors(key)) if errors.any?

    OpenStruct.new(success: true, **data_payload, message: message)
  end

  def success_response(response_data, response_message)
    OpenStruct.new(success: true, data: response_data, message: response_message)
  end

  def failure_response(response_data)
    OpenStruct.new(success: false, **response_data)
  end

  def translate(i18n_key, **params)
    I18n.t(i18n_key, **params, default: i18n_key.to_s)
  end

  def normalize_params(raw_params)
    hash = raw_params.respond_to?(:to_unsafe_h) ? raw_params.to_unsafe_h : raw_params.to_h
    hash.symbolize_keys
  end

  def sanitize_sql_like(string)
    ActiveRecord::Base.sanitize_sql_like(string)
  end

  def paginate(collection, page: 1, per_page: 20)
    page = [page.to_i, 1].max
    per_page = [[per_page.to_i, 1].max, 100].min
    offset = (page - 1) * per_page

    records = collection.limit(per_page).offset(offset)
    total = collection.count

    {
      records: records,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }
  end

  private

  def serialize_errors(error_key)
    V1::ErrorMessageSerializer.new(errors, error_key).serialized_json
  end

  def data_payload
    data.is_a?(Hash) ? data : { data: data }
  end
end
