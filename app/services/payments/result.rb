# frozen_string_literal: true

module Payments
  # Outcome of a gateway call. API errors are reported here instead of being raised.
  class Result
    attr_reader :data, :error

    def initialize(success:, data: {}, error: nil)
      @success = success
      @data = data
      @error = error
    end

    def success?
      @success
    end
  end
end
