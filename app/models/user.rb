# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  # bcrypt method that encrypts pw for each user

  belongs_to :role
  belongs_to :company
  has_many :reservations, dependent: :destroy

  validates :first_name, :last_name, :phone_number, presence: true
  validates :phone_number, numericality: true, format: { with: /\A\d{10}\z/, message: 'must be 10 digits' }
  validates :email, uniqueness: true, email_format: { message: 'is not looking good' }

  # validates :email, :URI::MAILTO:email
  # validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true

  validates :phone_number, uniqueness: true

  before_validation :normalize_fields

  def admin?
    role.name == 'admin'
  end

  def employee?
    role.name == 'user'
  end

  private

  def normalize_fields
    self.first_name = first_name&.downcase&.titleize
    self.last_name = last_name&.downcase&.titleize
  end
end
