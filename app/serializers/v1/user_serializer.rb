# frozen_string_literal: true

module V1
  class UserSerializer
    include JSONAPI::Serializer

    attributes :uid, :first_name, :last_name, :phone_number, :email, :created_at, :updated_at

    attribute :role_name do |user|
      user.role&.name
    end

    attribute :role_type do |user|
      user.role&.role_type
    end

    attribute :company_name do |user|
      user.company&.name
    end

    attribute :company_uid do |user|
      user.company&.uid
    end
  end
end
