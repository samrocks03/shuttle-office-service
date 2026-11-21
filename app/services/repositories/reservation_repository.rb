# frozen_string_literal: true

class ReservationRepository
  def self.scope_for(current_user)
    return Reservation.all if current_user[:admin]

    Reservation.where(user_id: current_user[:user_id])
  end

  def self.index(scope: Reservation.all, search: nil, sort_by: 'created_at', sort_order: 'desc')
    scope = scope.includes(:user, schedule: { bus: :company })
    if search.present?
      scope = scope.joins(:user, schedule: { bus: :company })
                   .where(
                     'users.first_name ILIKE ? OR users.last_name ILIKE ? OR schedules.start_point ILIKE ? OR companies.name ILIKE ?',
                     "%#{search}%", "%#{search}%", "%#{search}%", "%#{search}%"
                   )
    end
    scope.order("reservations.#{safe_column(sort_by, %w[created_at])} #{safe_order(sort_order)}")
  end

  def self.find_by_column(column, value)
    Reservation.find_by(column => value)
  end

  def self.find_by_uid(uid)
    Reservation.find_by(uid: uid)
  end

  def self.for_user(user_id)
    Reservation.includes(:user, schedule: { bus: :company })
               .where(user_id: user_id)
               .order(created_at: :desc)
  end

  private_class_method def self.safe_column(col, allowed)
    allowed.include?(col.to_s) ? col : allowed.first
  end

  private_class_method def self.safe_order(order)
    %w[asc desc].include?(order.to_s.downcase) ? order.downcase : 'asc'
  end
end
