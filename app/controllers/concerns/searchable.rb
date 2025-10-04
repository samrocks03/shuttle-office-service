# frozen_string_literal: true

module Searchable
  extend ActiveSupport::Concern

  def apply_search(collection, search_fields, search_term)
    return collection unless search_term.present?

    # Use PostgreSQL full-text search for better performance
    if postgresql?
      apply_pg_search(collection, search_fields, search_term)
    else
      apply_ilike_search(collection, search_fields, search_term)
    end
  end

  private

  def apply_pg_search(collection, search_fields, search_term)
    ts_query = search_term.split.map { |term| "#{term}:*" }.join(' & ')
    collection.where(
      "to_tsvector('english', #{search_fields.join(" || ' ' || ")}) @@ to_tsquery('english', ?)",
      ts_query
    )
  end

  def apply_ilike_search(collection, search_fields, search_term)
    conditions = search_fields.map { |field| "#{field} ILIKE ?" }.join(' OR ')
    values = Array.new(search_fields.length, "%#{search_term}%")
    collection.where(conditions, *values)
  end

  def postgresql?
    ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
  end
end
