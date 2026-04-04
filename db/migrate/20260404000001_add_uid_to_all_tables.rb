# frozen_string_literal: true

class AddUidToAllTables < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    %i[roles companies buses users schedules reservations].each do |table|
      add_column table, :uid, :uuid, null: false, default: -> { 'gen_random_uuid()' }
      add_index table, :uid, name: "index_#{table}_on_uid", unique: true
    end
  end
end
