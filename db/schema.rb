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

ActiveRecord::Schema[8.0].define(version: 2025_09_10_151034) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "target_id"
    t.string "target_type"
    t.string "action", null: false
    t.jsonb "changeset"
    t.string "ip"
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["target_type", "target_id"], name: "index_audit_logs_on_target_type_and_target_id"
    t.index ["target_type"], name: "index_audit_logs_on_target_type"
    t.index ["user_id", "action"], name: "index_audit_logs_on_user_id_and_action"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "credit_score_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "reason", null: false
    t.integer "delta", null: false
    t.jsonb "meta"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_credit_score_events_on_created_at"
    t.index ["reason"], name: "index_credit_score_events_on_reason"
    t.index ["user_id", "created_at"], name: "index_credit_score_events_on_user_id_and_created_at"
    t.index ["user_id", "reason"], name: "index_credit_score_events_on_user_id_and_reason"
    t.index ["user_id"], name: "index_credit_score_events_on_user_id"
    t.check_constraint "reason::text = ANY (ARRAY['on_time_payment'::character varying, 'overdue'::character varying, 'utilization'::character varying, 'kyc_bonus'::character varying, 'default'::character varying]::text[])", name: "credit_score_events_valid_reason"
  end

  create_table "idempotency_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "scope", null: false
    t.uuid "resource_id"
    t.string "resource_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key", "scope"], name: "index_idempotency_keys_on_key_and_scope", unique: true
    t.index ["resource_type", "resource_id"], name: "index_idempotency_keys_on_resource_type_and_resource_id"
  end

  create_table "loans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.integer "amount_cents", null: false
    t.integer "term_days", null: false
    t.string "product", null: false
    t.string "state", default: "pending", null: false
    t.date "due_on"
    t.integer "principal_outstanding_cents", default: 0, null: false
    t.integer "interest_accrued_cents", default: 0, null: false
    t.integer "penalty_accrued_cents", default: 0, null: false
    t.decimal "apr", precision: 10, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_on"], name: "index_loans_on_due_on"
    t.index ["state", "due_on"], name: "index_loans_on_state_and_due_on"
    t.index ["state"], name: "index_loans_on_state"
    t.index ["user_id", "state"], name: "index_loans_on_user_id_and_state"
    t.index ["user_id"], name: "index_loans_on_user_id"
    t.check_constraint "amount_cents > 0", name: "loans_amount_positive"
    t.check_constraint "product::text <> 'longterm'::text OR (term_days = ANY (ARRAY[270, 365]))", name: "loans_longterm_term_validation"
    t.check_constraint "product::text = ANY (ARRAY['micro'::character varying, 'extended'::character varying, 'longterm'::character varying]::text[])", name: "loans_valid_product"
    t.check_constraint "state::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'disbursed'::character varying, 'paid'::character varying, 'overdue'::character varying, 'defaulted'::character varying]::text[])", name: "loans_valid_state"
    t.check_constraint "term_days > 0", name: "loans_term_positive"
  end

  create_table "outbox_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.uuid "aggregate_id", null: false
    t.string "aggregate_type", null: false
    t.jsonb "payload"
    t.jsonb "headers"
    t.boolean "processed", default: false, null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["aggregate_type", "aggregate_id"], name: "index_outbox_events_on_aggregate_type_and_aggregate_id"
    t.index ["created_at"], name: "index_outbox_events_on_created_at"
    t.index ["name"], name: "index_outbox_events_on_name"
    t.index ["processed", "created_at"], name: "index_outbox_events_on_processed_and_created_at"
    t.index ["processed"], name: "index_outbox_events_on_processed"
  end

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "loan_id", null: false
    t.integer "amount_cents", null: false
    t.string "state", default: "pending", null: false
    t.string "gateway_ref"
    t.datetime "posted_at"
    t.jsonb "gateway_payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gateway_ref"], name: "index_payments_on_gateway_ref", unique: true
    t.index ["loan_id", "state"], name: "index_payments_on_loan_id_and_state"
    t.index ["loan_id"], name: "index_payments_on_loan_id"
    t.index ["posted_at"], name: "index_payments_on_posted_at"
    t.index ["state"], name: "index_payments_on_state"
    t.check_constraint "amount_cents > 0", name: "payments_amount_positive"
    t.check_constraint "state::text = ANY (ARRAY['pending'::character varying, 'cleared'::character varying, 'failed'::character varying]::text[])", name: "payments_valid_state"
  end

  create_table "promo_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", null: false
    t.string "kind", null: false
    t.integer "value_cents"
    t.decimal "percent_off", precision: 5, scale: 2
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "ends_at"], name: "index_promo_codes_on_active_and_ends_at"
    t.index ["active"], name: "index_promo_codes_on_active"
    t.index ["code"], name: "index_promo_codes_on_code", unique: true
    t.index ["ends_at"], name: "index_promo_codes_on_ends_at"
    t.check_constraint "kind::text = ANY (ARRAY['referral'::character varying, 'discount'::character varying]::text[])", name: "promo_codes_valid_kind"
    t.check_constraint "value_cents IS NOT NULL OR percent_off IS NOT NULL", name: "promo_codes_has_value"
  end

  create_table "referrals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "referrer_id", null: false
    t.uuid "referee_id", null: false
    t.string "status", default: "pending", null: false
    t.uuid "promo_code_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["promo_code_id"], name: "index_referrals_on_promo_code_id"
    t.index ["referee_id"], name: "index_referrals_on_referee_id"
    t.index ["referrer_id", "referee_id"], name: "index_referrals_on_referrer_id_and_referee_id", unique: true
    t.index ["referrer_id"], name: "index_referrals_on_referrer_id"
    t.index ["status"], name: "index_referrals_on_status"
    t.check_constraint "referrer_id <> referee_id", name: "referrals_no_self_referral"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'rewarded'::character varying]::text[])", name: "referrals_valid_status"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_otp_secret"
    t.string "encrypted_otp_secret_iv"
    t.string "encrypted_otp_secret_salt"
    t.boolean "otp_required_for_login", default: false, null: false
    t.text "otp_backup_codes"
    t.integer "consumed_timestep"
    t.datetime "last_sign_in_with_otp"
    t.string "role", default: "user", null: false
    t.string "full_name"
    t.integer "credit_limit_cents", default: 0, null: false
    t.integer "current_score", default: 600, null: false
    t.string "referral_code"
    t.string "kyc_status", default: "pending", null: false
    t.jsonb "kyc_payload"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["credit_limit_cents"], name: "index_users_on_credit_limit_cents"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["kyc_status"], name: "index_users_on_kyc_status"
    t.index ["otp_required_for_login"], name: "index_users_on_otp_required_for_login"
    t.index ["phone"], name: "index_users_on_phone", unique: true
    t.index ["referral_code"], name: "index_users_on_referral_code", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "credit_score_events", "users"
  add_foreign_key "loans", "users"
  add_foreign_key "payments", "loans"
  add_foreign_key "referrals", "promo_codes"
  add_foreign_key "referrals", "users", column: "referee_id"
  add_foreign_key "referrals", "users", column: "referrer_id"
end
