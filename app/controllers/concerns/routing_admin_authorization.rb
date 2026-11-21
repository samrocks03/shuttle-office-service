# frozen_string_literal: true

# Ability-based access for the routing admin endpoints (cities, stops, distances, fare tables).
# A denied check raises CanCan::AccessDenied, which ApplicationController renders as 403.
module RoutingAdminAuthorization
  extend ActiveSupport::Concern

  private

  def current_ability
    @current_ability ||= Ability.new(@current_user)
  end
end
