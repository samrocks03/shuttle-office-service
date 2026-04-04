# frozen_string_literal: true

class Role < ApplicationRecord
  include UidGenerator

  ROLE_TYPES = { admin: 0, user: 1, guest: 2 }.freeze

  enum role_type: ROLE_TYPES

  has_many :users, dependent: :nullify, inverse_of: :role

  validates :name, presence: true
  validates :role_type, presence: true

  def self.admin_role
    find_by(role_type: :admin)
  end

  def self.user_role
    find_by(role_type: :user)
  end

  def self.guest_role
    find_by(role_type: :guest)
  end
end
