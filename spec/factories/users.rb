# == Schema Information
#
# Table name: users
#
#  id                        :uuid             not null, primary key
#  confirmation_sent_at      :datetime
#  confirmation_token        :string
#  confirmed_at              :datetime
#  consumed_timestep         :integer
#  credit_limit_cents        :integer          default(0), not null
#  current_score             :integer          default(600), not null
#  current_sign_in_at        :datetime
#  current_sign_in_ip        :string
#  date_of_birth             :date
#  email                     :string           default(""), not null
#  encrypted_otp_secret      :string
#  encrypted_otp_secret_iv   :string
#  encrypted_otp_secret_salt :string
#  encrypted_password        :string           default(""), not null
#  failed_attempts           :integer          default(0), not null
#  full_name                 :string
#  kyc_payload               :jsonb
#  kyc_status                :string           default("pending"), not null
#  last_sign_in_at           :datetime
#  last_sign_in_ip           :string
#  last_sign_in_with_otp     :datetime
#  locked_at                 :datetime
#  otp_backup_codes          :text
#  otp_required_for_login    :boolean          default(FALSE), not null
#  phone                     :string
#  referral_code             :string
#  remember_created_at       :datetime
#  reset_password_sent_at    :datetime
#  reset_password_token      :string
#  role                      :string           default("user"), not null
#  sign_in_count             :integer          default(0), not null
#  unconfirmed_email         :string
#  unlock_token              :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token      (confirmation_token) UNIQUE
#  index_users_on_credit_limit_cents      (credit_limit_cents)
#  index_users_on_current_sign_in_at      (current_sign_in_at)
#  index_users_on_email                   (email) UNIQUE
#  index_users_on_kyc_status              (kyc_status)
#  index_users_on_last_sign_in_at         (last_sign_in_at)
#  index_users_on_otp_required_for_login  (otp_required_for_login)
#  index_users_on_phone                   (phone) UNIQUE
#  index_users_on_referral_code           (referral_code) UNIQUE
#  index_users_on_reset_password_token    (reset_password_token) UNIQUE
#  index_users_on_role                    (role)
#  index_users_on_sign_in_count           (sign_in_count)
#  index_users_on_unlock_token            (unlock_token) UNIQUE
#
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:full_name) { |n| "User #{n}" }
    password { "password123" }
    password_confirmation { "password123" }
    confirmed_at { Time.current }
    role { "user" }
    kyc_status { "approved" }
    credit_limit_cents { 5000_00 } # ₱5,000 default limit
    current_score { 600 }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :locked do
      locked_at { Time.current }
      failed_attempts { 5 }
    end

    trait :with_phone do
      sequence(:phone) { |n| "09171234#{n.to_s.rjust(3, '0')}" }
    end

    trait :kyc_approved do
      kyc_status { "approved" }
    end

    trait :kyc_pending do
      kyc_status { "pending" }
    end

    trait :kyc_pending_with_data do
      kyc_status { "pending" }
      date_of_birth { 25.years.ago }
      kyc_payload { {
        "gov_id_type" => "drivers_license",
        "gov_id_number_last4" => "1234",
        "address_line1" => "123 Test St, Manila",
        "date_of_birth" => 25.years.ago.to_s
      } }

      after(:build) do |user|
        # Attach sample files if Active Storage is available
        if defined?(ActiveStorage)
          user.kyc_gov_id_image.attach(
            io: StringIO.new("fake image data"),
            filename: "gov_id.jpg",
            content_type: "image/jpeg"
          )
          user.kyc_selfie_image.attach(
            io: StringIO.new("fake image data"),
            filename: "selfie.jpg",
            content_type: "image/jpeg"
          )
        end
      end
    end

    trait :kyc_rejected do
      kyc_status { "rejected" }
    end

    trait :kyc_complete do
      kyc_status { "approved" }
      date_of_birth { 25.years.ago }
      kyc_payload { {
        "gov_id_type" => "drivers_license",
        "gov_id_number_last4" => "1234",
        "address_line1" => "123 Test St, Manila",
        "date_of_birth" => 25.years.ago.to_s
      } }

      after(:build) do |user|
        # Attach sample files if Active Storage is available
        if defined?(ActiveStorage)
          user.kyc_gov_id_image.attach(
            io: StringIO.new("fake image data"),
            filename: "gov_id.jpg",
            content_type: "image/jpeg"
          )
          user.kyc_selfie_image.attach(
            io: StringIO.new("fake image data"),
            filename: "selfie.jpg",
            content_type: "image/jpeg"
          )
        end
      end
    end

    trait :staff do
      role { "staff" }
    end

    trait :admin do
      role { "admin" }
    end

    trait :with_2fa do
      otp_required_for_login { true }
      otp_backup_codes { "ABCD1234,EFGH5678,IJKL9012,MNOP3456,QRST7890,UVWX1234,YZAB5678,CDEF9012,GHIJ3456,KLMN7890" }
    end

    trait :high_credit_limit do
      credit_limit_cents { 50000_00 } # ₱50,000
    end

    trait :low_credit_score do
      current_score { 400 }
    end

    trait :high_credit_score do
      current_score { 800 }
    end
  end
end
