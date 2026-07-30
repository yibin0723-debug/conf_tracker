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

ActiveRecord::Schema[8.1].define(version: 2026_07_29_145232) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bookmarks", force: :cascade do |t|
    t.integer "conference_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["conference_id"], name: "index_bookmarks_on_conference_id"
    t.index ["user_id", "conference_id"], name: "index_bookmarks_on_user_id_and_conference_id", unique: true
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "conference_topics", force: :cascade do |t|
    t.bigint "conference_id", null: false
    t.datetime "created_at", null: false
    t.bigint "topic_id", null: false
    t.datetime "updated_at", null: false
    t.index ["conference_id", "topic_id"], name: "index_conference_topics_on_conference_and_topic", unique: true
    t.index ["conference_id"], name: "index_conference_topics_on_conference_id"
    t.index ["topic_id"], name: "index_conference_topics_on_topic_id"
  end

  create_table "conferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "ends_on", null: false
    t.string "location", null: false
    t.string "name", null: false
    t.string "rating"
    t.date "starts_on", null: false
    t.date "submission_deadline"
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["starts_on"], name: "index_conferences_on_starts_on"
    t.index ["submission_deadline"], name: "index_conferences_on_submission_deadline"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "topics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_topics_on_lower_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "bookmarks", "conferences"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "conference_topics", "conferences"
  add_foreign_key "conference_topics", "topics"
  add_foreign_key "sessions", "users"
end
