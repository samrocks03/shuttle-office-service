# frozen_string_literal: true

class AddPaymentStateToReservations < ActiveRecord::Migration[7.0]
  ACTIVE_STATUSES = "status IN ('pending_payment','confirmed')"

  def change
    add_column :reservations, :status, :string, null: false, default: 'confirmed'
    add_column :reservations, :fare_amount_minor, :integer
    add_column :reservations, :currency, :string
    add_column :reservations, :fare_breakdown, :jsonb
    add_column :reservations, :hold_expires_at, :datetime
    add_column :reservations, :cancelled_at, :datetime
    add_reference :reservations, :fare_table, null: true, foreign_key: true

    # An employee may book again after an expired or cancelled attempt, so only active
    # reservations are unique per (schedule, user).
    remove_index :reservations, column: %i[schedule_id user_id], name: 'index_reservations_on_schedule_and_user',
                                unique: true
    add_index :reservations, %i[schedule_id user_id], unique: true, where: ACTIVE_STATUSES,
                                                      name: 'index_reservations_on_schedule_and_user'
  end
end
