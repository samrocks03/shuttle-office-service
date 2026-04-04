# frozen_string_literal: true

class UserRepository
  def self.index(search: nil, sort_by: 'first_name', sort_order: 'asc')
    scope = User.includes(:role, :company)
    if search.present?
      scope = scope.where(
        'users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ? OR users.phone_number ILIKE ?',
        "%#{search}%", "%#{search}%", "%#{search}%", "%#{search}%"
      )
    end
    scope.order("users.#{safe_column(sort_by, %w[first_name last_name email created_at])} #{safe_order(sort_order)}")
  end

  def self.find_by_column(column, value)
    User.find_by(column => value)
  end

  def self.find_by_uid(uid)
    User.find_by(uid: uid)
  end

  def self.find_by_email(email)
    User.find_by(email: email)
  end

  def self.search(query)
    index(search: query)
  end

  private_class_method def self.safe_column(col, allowed)
    allowed.include?(col.to_s) ? col : allowed.first
  end

  private_class_method def self.safe_order(order)
    %w[asc desc].include?(order.to_s.downcase) ? order.downcase : 'asc'
  end
end
