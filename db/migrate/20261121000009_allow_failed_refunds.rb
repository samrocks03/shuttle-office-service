# frozen_string_literal: true

# A refund the gateway refused never gets a gateway id. Keep it as a failed row with the error so
# admins can see and retry it.
class AllowFailedRefunds < ActiveRecord::Migration[7.0]
  def change
    change_column_null :refunds, :gateway_refund_id, true
    add_column :refunds, :last_error, :text
  end
end
