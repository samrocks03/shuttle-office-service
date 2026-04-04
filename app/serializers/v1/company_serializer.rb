# frozen_string_literal: true

module V1
  class CompanySerializer
    include JSONAPI::Serializer

    attributes :uid, :name, :location, :created_at, :updated_at
  end
end
