# frozen_string_literal: true

class ScheduleRepository
  def self.index(search: nil, sort_by: 'date', sort_order: 'desc', bus_id: nil, start_point: nil, date: nil)
    scope = Schedule.includes(bus: :company)

    scope = scope.where(bus_id: bus_id) if bus_id.present?
    scope = scope.where('schedules.start_point ILIKE ?', "%#{start_point}%") if start_point.present?
    scope = scope.where(date: date) if date.present?
    if search.present?
      scope = scope.joins(bus: :company)
                   .where(
                     'schedules.start_point ILIKE ? OR companies.name ILIKE ? OR CAST(schedules.date AS TEXT) ILIKE ?',
                     "%#{search}%", "%#{search}%", "%#{search}%"
                   )
    end
    scope.order("schedules.#{safe_column(sort_by,
                                         %w[date start_point available_seats created_at])} #{safe_order(sort_order)}")
  end

  def self.find_by_column(column, value)
    Schedule.find_by(column => value)
  end

  def self.find_by_uid(uid)
    Schedule.find_by(uid: uid)
  end

  def self.filter_by_bus(bus_id)
    index(bus_id: bus_id)
  end

  private_class_method def self.safe_column(col, allowed)
    allowed.include?(col.to_s) ? col : allowed.first
  end

  private_class_method def self.safe_order(order)
    %w[asc desc].include?(order.to_s.downcase) ? order.downcase : 'asc'
  end
end
