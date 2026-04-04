# frozen_string_literal: true

class AddCheckConstraintToSchedulesAvailableSeats < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      ALTER TABLE schedules
      ADD CONSTRAINT available_seats_non_negative
      CHECK (available_seats >= 0);
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE schedules
      DROP CONSTRAINT available_seats_non_negative;
    SQL
  end
end
