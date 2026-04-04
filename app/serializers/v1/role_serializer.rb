# frozen_string_literal: true

module V1
  class RoleSerializer
    include JSONAPI::Serializer

    attributes :uid, :name, :role_type, :created_at, :updated_at
  end
end
