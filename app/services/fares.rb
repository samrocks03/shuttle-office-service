# frozen_string_literal: true

module Fares
  class UnknownPolicy < StandardError; end

  Quote = Struct.new(:amount_minor, :currency, :distance_km, :slab_label, :fare_table_id, keyword_init: true)
end
