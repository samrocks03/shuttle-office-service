# frozen_string_literal: true

class RoleRepository
  def self.index(search: nil, sort_by: 'name', sort_order: 'asc')
    scope = Role.all
    scope = scope.where('name ILIKE ?', "%#{search}%") if search.present?
    scope.order("#{safe_column(sort_by, %w[name role_type created_at])} #{safe_order(sort_order)}")
  end

  def self.find_by_column(column, value)
    Role.find_by(column => value)
  end

  def self.find_by_uid(uid)
    Role.find_by(uid: uid)
  end

  private_class_method def self.safe_column(col, allowed)
    allowed.include?(col.to_s) ? col : allowed.first
  end

  private_class_method def self.safe_order(order)
    %w[asc desc].include?(order.to_s.downcase) ? order.downcase : 'asc'
  end
end
