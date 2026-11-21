# frozen_string_literal: true

class NullifyStopDistancesOverriddenByOnUserDelete < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :stop_distances, :users, column: :overridden_by_id
    add_foreign_key :stop_distances, :users, column: :overridden_by_id, on_delete: :nullify
  end
end
