# frozen_string_literal: true

class CreatePaymentsRefundsWebhookEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.uuid :uid, null: false, default: -> { 'gen_random_uuid()' }
      t.references :reservation, null: false, foreign_key: true
      t.string :gateway, null: false, default: 'hyperswitch'
      t.string :gateway_payment_id, null: false
      t.string :status, null: false
      t.integer :amount_minor, null: false
      t.string :currency, null: false
      t.string :connector
      t.text :last_error
      t.jsonb :raw, null: false, default: {}

      t.timestamps
    end

    add_index :payments, :uid, unique: true, name: 'index_payments_on_uid'
    add_index :payments, :gateway_payment_id, unique: true
    add_index :payments, %i[reservation_id status]

    create_table :refunds do |t|
      t.uuid :uid, null: false, default: -> { 'gen_random_uuid()' }
      t.references :payment, null: false, foreign_key: true
      t.string :gateway_refund_id, null: false
      t.integer :amount_minor, null: false
      t.string :status, null: false, default: 'pending'
      t.string :reason

      t.timestamps
    end

    add_index :refunds, :uid, unique: true, name: 'index_refunds_on_uid'
    add_index :refunds, :gateway_refund_id, unique: true

    create_table :payment_webhook_events do |t|
      t.uuid :uid, null: false, default: -> { 'gen_random_uuid()' }
      t.string :gateway, null: false
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.string :gateway_payment_id
      t.datetime :received_at, null: false

      t.timestamps
    end

    add_index :payment_webhook_events, :uid, unique: true, name: 'index_payment_webhook_events_on_uid'
    add_index :payment_webhook_events, :event_id, unique: true
  end
end
