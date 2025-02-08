# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new

    # role.name == "admin"
    # admin = role.find_by(name: "admin")

    # byebug
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
      cannot %i[update destroy], Reservation # User cannot update or delete reservations
    else
      # Default guest abilities
      cannot :manage, :all
    end
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/blob/develop/docs/define_check_abilities.md
  end
end
