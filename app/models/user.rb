# frozen_string_literal: true

class User < ApplicationRecord
  include UidGenerator

  has_secure_password

  belongs_to :role, inverse_of: :users
  belongs_to :company, inverse_of: :users
  has_many :reservations, dependent: :destroy, inverse_of: :user

  validates :first_name, :last_name, :phone_number, presence: true
  validates :phone_number, numericality: true, format: { with: /\A\d{10}\z/, message: 'must be 10 digits' }
  validates :email, uniqueness: true, email_format: { message: 'is not looking good' }
  validates :phone_number, uniqueness: true

  before_validation :normalize_fields

  def admin?
    role&.admin?
  end

  def employee?
    role&.user?
  end

  def guest?
    role&.guest?
  end

  private

  def normalize_fields
    self.first_name = first_name&.downcase&.titleize
    self.last_name = last_name&.downcase&.titleize
  end
end
