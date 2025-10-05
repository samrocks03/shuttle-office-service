# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    if user.admin? # This will contain admin role
      can :manage, :all
    elsif user.employee? # User role
      can [:create], User
      can %i[update read], User, id: user.id
      cannot %i[read delete], User

      cannot %i[update delete], Bus # user cannot manage buses
      cannot %i[update delete], Company # user cannot manage companies
      cannot %i[create delete update], Schedule # user cannot manage schedules

      can :read, Company
      can :read, Schedule # user can read schedule
      can %i[create read], Reservation, user_id: user.id # can view only his reservation
      cannot %i[update delete], Reservation # User cannot update or delete reservations

    elsif user.guest?
      can %i[create], User, id: user.id
      can %i[create], Reservation, user_id: user.id
      cannot %i[update delete update], User
      cannot %i[update delete update], Reservation
      cannot %i[create delete update], Schedule
      cannot %i[create delete update], Bus
      cannot %i[create delete update], Company
    else
      # Default guest abilities
      cannot :manage, :all
    end
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/blob/develop/docs/define_check_abilities.md
  end
end
