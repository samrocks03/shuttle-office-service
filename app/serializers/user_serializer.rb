# frozen_string_literal: true

class UserSerializer < ActiveModel::Serializer
  attributes :id, :first_name, :last_name, :phone_number, :email, :role_id, :company_id

  belongs_to :role, if: -> { instance_options[:include_role] }
  belongs_to :company, if: -> { instance_options[:include_company] }
  has_many :reservations, if: -> { instance_options[:include_reservations] }

  attribute :role_name do
    object.role&.name
  end

  attribute :role_type do
    object.role&.role_type
  end

  attribute :company_name do
    object.company&.name
  end

  attribute :company_location do
    object.company&.location
  end

  attribute :reservations_count, if: -> { instance_options[:include_reservations_count] } do
    object.reservations.count
  end

  attribute :has_reservations, if: -> { instance_options[:include_has_reservations] } do
    object.reservations.any?
  end

  def attributes(*args)
    hash = super
    unless instance_options[:include_timestamps]
      hash.delete(:created_at)
      hash.delete(:updated_at)
    end
    hash
  end
end
