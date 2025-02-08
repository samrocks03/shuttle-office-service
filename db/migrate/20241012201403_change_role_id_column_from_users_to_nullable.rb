# frozen_string_literal: true

class ChangeRoleIdColumnFromUsersToNullable < ActiveRecord::Migration[7.0]
  def change
    change_column :users, :role_id, :bigint, null: true
  end
end
