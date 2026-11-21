# frozen_string_literal: true

module Distances
  Cell = Struct.new(:km, :minutes)

  class UnknownProvider < StandardError; end
  class ProviderError < StandardError; end
end
