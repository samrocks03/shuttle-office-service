# frozen_string_literal: true

class CompanySerializer < ActiveModel::Serializer
  attributes :id, :name, :location

  attribute :users_count, if: -> { instance_options[:include_users_count] } do
    object.users.count
  end

  attribute :buses_count, if: -> { instance_options[:include_buses_count] } do
    object.buses.count
  end

  attribute :created_at do
    object.created_at.iso8601
  end

  attribute :updated_at do
    object.updated_at.iso8601
  end
end
