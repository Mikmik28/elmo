# == Schema Information
#
# Table name: users
#
#  id                        :uuid             not null, primary key
#  confirmation_sent_at      :datetime
#  confirmation_token        :string
#  confirmed_at              :datetime
#  consumed_timestep         :integer
#  email                     :string           default(""), not null
#  encrypted_otp_secret      :string
#  encrypted_otp_secret_iv   :string
#  encrypted_otp_secret_salt :string
#  encrypted_password        :string           default(""), not null
#  failed_attempts           :integer          default(0), not null
#  last_sign_in_with_otp     :datetime
#  locked_at                 :datetime
#  otp_backup_codes          :text
#  otp_required_for_login    :boolean          default(FALSE), not null
#  phone                     :string
#  remember_created_at       :datetime
#  reset_password_sent_at    :datetime
#  reset_password_token      :string
#  role                      :string           default("user"), not null
#  unconfirmed_email         :string
#  unlock_token              :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token      (confirmation_token) UNIQUE
#  index_users_on_email                   (email) UNIQUE
#  index_users_on_otp_required_for_login  (otp_required_for_login)
#  index_users_on_reset_password_token    (reset_password_token) UNIQUE
#  index_users_on_role                    (role)
#  index_users_on_unlock_token            (unlock_token) UNIQUE
#
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    confirmed_at { Time.current }
    role { "user" }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :locked do
      locked_at { Time.current }
      failed_attempts { 5 }
    end

    trait :with_phone do
      phone { "+639171234567" }
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
  end
end
