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
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :confirmable, :lockable,
         :two_factor_authenticatable,
         otp_secret_encryption_key: Rails.application.credentials.dig(:otp_secret_encryption_key)

  # Enums
  enum :role, { user: "user", staff: "staff", admin: "admin" }, suffix: true

  # Validations
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is invalid" }
  validates :phone, format: { with: /\A[\+]?[\d\s\-\(\)]+\z/, message: "must be a valid phone number" }, allow_blank: true
  validates :password, confirmation: true
  validates :password_confirmation, presence: true, if: :password_required?
  validates :role, presence: true, inclusion: { in: roles.keys }

  # Callbacks
  before_save :normalize_email
  before_save :normalize_phone
  before_create :enforce_2fa_for_privileged_roles

  # 2FA Methods
  def backup_codes
    otp_backup_codes&.split(",") || []
  end

  def generate_backup_codes!
    codes = 10.times.map { SecureRandom.alphanumeric(8).upcase }
    self.otp_backup_codes = codes.join(",")
    codes
  end

  def invalidate_backup_code!(code)
    return false unless backup_codes.include?(code)

    remaining_codes = backup_codes - [ code ]
    self.otp_backup_codes = remaining_codes.join(",")
    save!
    true
  end

  def backup_codes_generated?
    otp_backup_codes.present?
  end

  def two_factor_enabled?
    otp_required_for_login?
  end

  def enable_two_factor!
    self.otp_required_for_login = true
    generate_backup_codes! unless backup_codes_generated?
    save!
  end

  def disable_two_factor!
    self.otp_required_for_login = false
    self.otp_backup_codes = nil
    self.encrypted_otp_secret = nil
    self.encrypted_otp_secret_iv = nil
    self.encrypted_otp_secret_salt = nil
    self.consumed_timestep = nil
    self.last_sign_in_with_otp = nil
    save!
  end

  def requires_two_factor?
    staff_role? || admin_role?
  end

  def qr_code_uri
    return nil unless otp_secret.present?

    issuer = Rails.application.class.module_parent_name
    label = "#{issuer}:#{email}"

    ROTP::TOTP.new(otp_secret, issuer: issuer).provisioning_uri(label)
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def normalize_phone
    self.phone = phone.gsub(/\D/, "") if phone.present?
  end

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  def enforce_2fa_for_privileged_roles
    if requires_two_factor?
      self.otp_required_for_login = true
    end
  end
end
