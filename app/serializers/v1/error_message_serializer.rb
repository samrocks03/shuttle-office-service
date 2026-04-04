# frozen_string_literal: true

module V1
  class ErrorMessageSerializer
    def initialize(errors, key)
      @errors = errors
      @key = key
    end

    def serialized_json
      { errors: { base: @errors.full_messages }, error_key: @key }
    end
  end
end
