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

ActiveRecord::Schema[8.1].define(version: 2026_11_11_200000) do
  create_table "accounts", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "email", null: false
    t.string "email_normalized", null: false
    t.string "role", null: false
    t.string "password_digest", null: false
    t.datetime "email_confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_normalized"], name: "index_accounts_on_email_normalized", unique: true
  end

  create_table "email_confirmations", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "account_id", limit: 36, null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_email_confirmations_on_account_id", unique: true
    t.index ["token_digest"], name: "index_email_confirmations_on_token_digest", unique: true
  end

  create_table "enrolments", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "family_unit_id", limit: 36, null: false
    t.string "locality_id", limit: 36, null: false
    t.datetime "submitted_at", null: false
    t.boolean "on_behalf", null: false
    t.string "consent_text", null: false
    t.string "enroler_contact", null: false
    t.string "email", null: false
    t.string "place_name", null: false
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "family_phone", null: false
    t.string "how_to_find", null: false
    t.json "help", null: false
    t.string "other_help", null: false
    t.datetime "visit_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_unit_id"], name: "index_enrolments_on_family_unit_id", unique: true
    t.index ["locality_id"], name: "index_enrolments_on_locality_id"
  end

  create_table "family_members", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "family_unit_id", limit: 36, null: false
    t.string "role", null: false
    t.integer "position", null: false
    t.string "name", null: false
    t.integer "age"
    t.string "gender", null: false
    t.string "description", null: false
    t.boolean "in_education", null: false
    t.boolean "working", null: false
    t.string "job", null: false
    t.integer "monthly_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_unit_id"], name: "index_family_members_on_family_unit_id"
  end

  create_table "family_units", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "localities", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "name", null: false
    t.decimal "latitude"
    t.decimal "longitude"
    t.integer "radius_metres"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "locality_assignments", id: { type: :string, limit: 36 }, force: :cascade do |t|
    t.string "account_id", limit: 36, null: false
    t.string "locality_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["locality_id"], name: "index_locality_assignments_on_locality_id"
  end

  add_foreign_key "email_confirmations", "accounts"
  add_foreign_key "enrolments", "family_units"
  add_foreign_key "enrolments", "localities"
  add_foreign_key "family_members", "family_units"
  add_foreign_key "locality_assignments", "accounts"
  add_foreign_key "locality_assignments", "localities"
end
