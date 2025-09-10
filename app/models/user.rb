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
#  unconfirmed_email         :string
#  unlock_token              :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token      (confirmation_token) UNIQUE
#  index_users_on_credit_limit_cents      (credit_limit_cents)
#  index_users_on_email                   (email) UNIQUE
#  index_users_on_kyc_status              (kyc_status)
#  index_users_on_otp_required_for_login  (otp_required_for_login)
#  index_users_on_phone                   (phone) UNIQUE
#  index_users_on_referral_code           (referral_code) UNIQUE
#  index_users_on_reset_password_token    (reset_password_token) UNIQUE
#  index_users_on_role                    (role)
#  index_users_on_unlock_token            (unlock_token) UNIQUE
#
class User < ApplicationRecord
  include EnumAliases

  # Include default devise modules. Others available are:
  # :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :confirmable, :lockable,
         :two_factor_authenticatable,
         otp_secret_encryption_key: Rails.application.credentials.dig(:otp_secret_encryption_key)

  # Associations
  has_many :loans, dependent: :destroy
  has_many :referrals_as_referrer, class_name: "Referral", foreign_key: "referrer_id", dependent: :destroy
  has_many :referrals_as_referee, class_name: "Referral", foreign_key: "referee_id", dependent: :destroy
  has_many :credit_score_events, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  # Active Storage attachments for KYC
  has_one_attached :kyc_gov_id_image
  has_one_attached :kyc_selfie_image

  # Enums
  enum :role, { user: "user", staff: "staff", admin: "admin" }, suffix: true
  enum :kyc_status, { pending: "pending", approved: "approved", rejected: "rejected" }, prefix: :kyc

  # Create unprefixed aliases for kyc_status predicates (e.g., approved?, rejected?)
  alias_unprefixed_enum_predicates :kyc_status, prefix: :kyc

  # Validations
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is invalid" }
  validates :phone, format: { with: /\A[\+]?[\d\s\-\(\)]+\z/, message: "must be a valid phone number" },
                    uniqueness: true, allow_blank: true
  validates :password, confirmation: true
  validates :password_confirmation, presence: true, if: :password_required?
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :kyc_status, presence: true, inclusion: { in: kyc_statuses.keys }
  validates :referral_code, uniqueness: true, allow_blank: true
  validates :credit_limit_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :current_score, presence: true, numericality: { in: 300..900 }
  validates :date_of_birth, presence: true, if: :kyc_complete?
  validate :date_of_birth_reasonable, if: :date_of_birth?

  # KYC file validations
  validate :kyc_gov_id_image_format, if: -> { kyc_gov_id_image.attached? }
  validate :kyc_selfie_image_format, if: -> { kyc_selfie_image.attached? }

  # Callbacks
  before_save :normalize_email
  before_save :normalize_phone
  before_create :enforce_2fa_for_privileged_roles
  before_create :generate_referral_code

  # Scopes
  scope :kyc_approved, -> { where(kyc_status: "approved") }
  scope :with_active_loans, -> { joins(:loans).where(loans: { state: %w[disbursed overdue] }) }

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

  # Lending-specific methods
  def has_overdue_loans?
    loans.where(state: "overdue").exists?
  end

  def credit_limit_in_pesos
    credit_limit_cents / 100.0
  end

  def credit_limit_in_pesos=(amount)
    self.credit_limit_cents = (amount.to_f * 100).to_i
  end

  # KYC methods
  def kyc_submitted?
    kyc_gov_id_image.attached? && kyc_selfie_image.attached?
  end

  def kyc_complete?
    kyc_submitted? && kyc_payload.present?
  end

  def age
    return nil unless date_of_birth.present?

    ((Date.current - date_of_birth).to_f / 365.25).floor
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

  def generate_referral_code
    return if referral_code.present?

    loop do
      code = SecureRandom.alphanumeric(8).upcase
      if self.class.where(referral_code: code).empty?
        self.referral_code = code
        break
      end
    end
  end

  def kyc_gov_id_image_format
    return unless kyc_gov_id_image.attached?

    unless kyc_gov_id_image.content_type.in?(%w[image/png image/jpeg])
      errors.add(:kyc_gov_id_image, "must be a PNG or JPEG image")
    end

    if kyc_gov_id_image.byte_size > 5.megabytes
      errors.add(:kyc_gov_id_image, "must be less than 5MB")
    end
  end

  def kyc_selfie_image_format
    return unless kyc_selfie_image.attached?

    unless kyc_selfie_image.content_type.in?(%w[image/png image/jpeg])
      errors.add(:kyc_selfie_image, "must be a PNG or JPEG image")
    end

    if kyc_selfie_image.byte_size > 5.megabytes
      errors.add(:kyc_selfie_image, "must be less than 5MB")
    end
  end

  def date_of_birth_reasonable
    return unless date_of_birth.present?

    if date_of_birth > Date.current
      errors.add(:date_of_birth, "cannot be in the future")
    elsif date_of_birth < 120.years.ago
      errors.add(:date_of_birth, "must be within the last 120 years")
    elsif date_of_birth > 18.years.ago
      errors.add(:date_of_birth, "must be at least 18 years old")
    end
  end
end
