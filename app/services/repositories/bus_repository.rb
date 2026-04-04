# frozen_string_literal: true

class BusRepository
  def self.index(search: nil, sort_by: 'number', sort_order: 'asc')
    scope = Bus.includes(:company)
    if search.present?
      scope = scope.joins(:company)
                   .where('buses.number ILIKE ? OR buses.model ILIKE ? OR companies.name ILIKE ?',
                          "%#{search}%", "%#{search}%", "%#{search}%")
    end
    scope.order("buses.#{safe_column(sort_by, %w[number model capacity created_at])} #{safe_order(sort_order)}")
  end

  def self.find_by_column(column, value)
    Bus.find_by(column => value)
  end

  def self.find_by_uid(uid)
    Bus.find_by(uid: uid)
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
