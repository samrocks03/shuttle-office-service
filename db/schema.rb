# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_11_21_000009) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "buses", force: :cascade do |t|
    t.text "number"
    t.integer "capacity"
    t.text "model"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.string "service_class", default: "non_ac", null: false
    t.index ["company_id"], name: "index_buses_on_company_id"
    t.index ["number"], name: "index_buses_on_number", unique: true
    t.index ["uid"], name: "index_buses_on_uid", unique: true
  end

  create_table "cities", force: :cascade do |t|
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.string "name", null: false
    t.string "country_code", null: false
    t.string "currency", null: false
    t.string "time_zone", null: false
    t.string "distance_provider", default: "osrm", null: false
    t.boolean "payments_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_cities_on_uid", unique: true
  end

  create_table "companies", force: :cascade do |t|
    t.text "name", null: false
    t.text "location", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "city_id"
    t.index ["city_id"], name: "index_companies_on_city_id"
    t.index ["name"], name: "index_companies_on_name", unique: true
    t.index ["uid"], name: "index_companies_on_uid", unique: true
  end

  create_table "fare_slabs", force: :cascade do |t|
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "fare_table_id", null: false
    t.decimal "up_to_km", precision: 8, scale: 3, null: false
    t.integer "amount_minor", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fare_table_id", "up_to_km"], name: "index_fare_slabs_on_fare_table_id_and_up_to_km", unique: true
    t.index ["fare_table_id"], name: "index_fare_slabs_on_fare_table_id"
    t.index ["uid"], name: "index_fare_slabs_on_uid", unique: true
  end

  create_table "fare_tables", force: :cascade do |t|
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "city_id", null: false
    t.string "service_class", null: false
    t.string "currency", null: false
    t.string "policy", default: "slab", null: false
    t.date "effective_from", null: false
    t.boolean "active", default: true, null: false
    t.decimal "step_km", precision: 8, scale: 3
    t.integer "step_amount_minor"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id", "service_class", "effective_from"], name: "index_fare_tables_on_lookup"
    t.index ["city_id"], name: "index_fare_tables_on_city_id"
    t.index ["uid"], name: "index_fare_tables_on_uid", unique: true
  end

  create_table "payment_webhook_events", force: :cascade do |t|
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.string "gateway", null: false
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.string "gateway_payment_id"
    t.datetime "received_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_payment_webhook_events_on_event_id", unique: true
    t.index ["uid"], name: "index_payment_webhook_events_on_uid", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "reservation_id", null: false
    t.string "gateway", default: "hyperswitch", null: false
    t.string "gateway_payment_id", null: false
    t.string "status", null: false
    t.integer "amount_minor", null: false
    t.string "currency", null: false
    t.string "connector"
    t.text "last_error"
    t.jsonb "raw", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gateway_payment_id"], name: "index_payments_on_gateway_payment_id", unique: true
    t.index ["reservation_id", "status"], name: "index_payments_on_reservation_id_and_status"
    t.index ["reservation_id"], name: "index_payments_on_reservation_id"
    t.index ["uid"], name: "index_payments_on_uid", unique: true
  end

  create_table "refunds", force: :cascade do |t|
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "payment_id", null: false
    t.string "gateway_refund_id"
    t.integer "amount_minor", null: false
    t.string "status", default: "pending", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "last_error"
    t.index ["gateway_refund_id"], name: "index_refunds_on_gateway_refund_id", unique: true
    t.index ["payment_id"], name: "index_refunds_on_payment_id"
    t.index ["uid"], name: "index_refunds_on_uid", unique: true
  end

  create_table "reservations", force: :cascade do |t|
    t.bigint "schedule_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.string "status", default: "confirmed", null: false
    t.integer "fare_amount_minor"
    t.string "currency"
    t.jsonb "fare_breakdown"
    t.datetime "hold_expires_at"
    t.datetime "cancelled_at"
    t.bigint "fare_table_id"
    t.index ["fare_table_id"], name: "index_reservations_on_fare_table_id"
    t.index ["schedule_id", "user_id"], name: "index_reservations_on_schedule_and_user", unique: true, where: "((status)::text = ANY ((ARRAY['pending_payment'::character varying, 'confirmed'::character varying])::text[]))"
    t.index ["schedule_id"], name: "index_reservations_on_schedule_id"
    t.index ["uid"], name: "index_reservations_on_uid", unique: true
    t.index ["user_id"], name: "index_reservations_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.text "name", null: false
    t.integer "role_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["role_type"], name: "index_roles_on_role_type"
    t.index ["uid"], name: "index_roles_on_uid", unique: true
  end

  create_table "schedules", force: :cascade do |t|
    t.text "start_point"
    t.bigint "bus_id", null: false
    t.date "date"
    t.time "arrival_time"
    t.time "departure_time"
    t.integer "available_seats"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "from_stop_id"
    t.bigint "to_stop_id"
    t.index ["bus_id", "date"], name: "index_schedules_on_bus_id_and_date"
    t.index ["bus_id"], name: "index_schedules_on_bus_id"
    t.index ["date"], name: "index_schedules_on_date"
    t.index ["from_stop_id"], name: "index_schedules_on_from_stop_id"
    t.index ["to_stop_id"], name: "index_schedules_on_to_stop_id"
    t.index ["uid"], name: "index_schedules_on_uid", unique: true
    t.check_constraint "available_seats >= 0", name: "available_seats_non_negative"
  end

  create_table "stop_distances", force: :cascade do |t|
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "from_stop_id", null: false
    t.bigint "to_stop_id", null: false
    t.decimal "computed_km", precision: 8, scale: 3
    t.integer "computed_minutes"
    t.string "source"
    t.datetime "computed_at"
    t.decimal "override_km", precision: 8, scale: 3
    t.string "override_reason"
    t.bigint "overridden_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_stop_id", "to_stop_id"], name: "index_stop_distances_on_from_stop_id_and_to_stop_id", unique: true
    t.index ["from_stop_id"], name: "index_stop_distances_on_from_stop_id"
    t.index ["overridden_by_id"], name: "index_stop_distances_on_overridden_by_id"
    t.index ["to_stop_id"], name: "index_stop_distances_on_to_stop_id"
    t.index ["uid"], name: "index_stop_distances_on_uid", unique: true
    t.check_constraint "from_stop_id <> to_stop_id", name: "stop_distances_distinct_stops"
  end

  create_table "stops", force: :cascade do |t|
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "city_id", null: false
    t.bigint "company_id"
    t.string "name", null: false
    t.string "kind", null: false
    t.decimal "latitude", precision: 10, scale: 7, null: false
    t.decimal "longitude", precision: 10, scale: 7, null: false
    t.string "osm_ref"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id", "kind", "active"], name: "index_stops_on_city_id_and_kind_and_active"
    t.index ["city_id"], name: "index_stops_on_city_id"
    t.index ["company_id"], name: "index_stops_on_company_id"
    t.index ["uid"], name: "index_stops_on_uid", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone_number", null: false
    t.string "password_digest", null: false
    t.text "email", null: false
    t.bigint "company_id", null: false
    t.bigint "role_id", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "buses", "companies"
  add_foreign_key "companies", "cities"
  add_foreign_key "fare_slabs", "fare_tables"
  add_foreign_key "fare_tables", "cities"
  add_foreign_key "payments", "reservations"
  add_foreign_key "refunds", "payments"
  add_foreign_key "reservations", "fare_tables"
  add_foreign_key "reservations", "schedules"
  add_foreign_key "reservations", "users"
  add_foreign_key "schedules", "buses"
  add_foreign_key "schedules", "stops", column: "from_stop_id"
  add_foreign_key "schedules", "stops", column: "to_stop_id"
  add_foreign_key "stop_distances", "stops", column: "from_stop_id"
  add_foreign_key "stop_distances", "stops", column: "to_stop_id"
  add_foreign_key "stop_distances", "users", column: "overridden_by_id", on_delete: :nullify
  add_foreign_key "stops", "cities"
  add_foreign_key "stops", "companies"
  add_foreign_key "users", "companies"
  add_foreign_key "users", "roles"
end
