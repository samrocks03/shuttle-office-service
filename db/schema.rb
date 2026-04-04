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

ActiveRecord::Schema[7.0].define(version: 2026_04_04_000004) do
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
    t.index ["company_id"], name: "index_buses_on_company_id"
    t.index ["number"], name: "index_buses_on_number", unique: true
    t.index ["uid"], name: "index_buses_on_uid", unique: true
  end

  create_table "companies", force: :cascade do |t|
    t.text "name", null: false
    t.text "location", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["name"], name: "index_companies_on_name", unique: true
    t.index ["uid"], name: "index_companies_on_uid", unique: true
  end

  create_table "reservations", force: :cascade do |t|
    t.bigint "schedule_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["schedule_id", "user_id"], name: "index_reservations_on_schedule_and_user", unique: true
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
    t.index ["bus_id", "date"], name: "index_schedules_on_bus_id_and_date"
    t.index ["bus_id"], name: "index_schedules_on_bus_id"
    t.index ["date"], name: "index_schedules_on_date"
    t.index ["uid"], name: "index_schedules_on_uid", unique: true
    t.check_constraint "available_seats >= 0", name: "available_seats_non_negative"
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
  add_foreign_key "reservations", "schedules"
  add_foreign_key "reservations", "users"
  add_foreign_key "schedules", "buses"
  add_foreign_key "users", "companies"
  add_foreign_key "users", "roles"
end
