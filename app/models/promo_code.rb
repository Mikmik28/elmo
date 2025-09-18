# == Schema Information
#
# Table name: promo_codes
#
#  id          :uuid             not null, primary key
#  active      :boolean          default(TRUE), not null
#  code        :string           not null
#  ends_at     :datetime
#  kind        :string           not null
#  percent_off :decimal(5, 2)
#  starts_at   :datetime
#  value_cents :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_promo_codes_on_active              (active)
#  index_promo_codes_on_active_and_ends_at  (active,ends_at)
#  index_promo_codes_on_code                (code) UNIQUE
#  index_promo_codes_on_ends_at             (ends_at)
#
class PromoCode < ApplicationRecord
  include EnumAliases

  has_many :referrals, dependent: :nullify

  # Enums
  enum :kind, { referral: "referral", discount: "discount" }, suffix: true

  # Create unprefixed aliases for kind predicates (e.g., referral?, discount?)
  alias_unprefixed_enum_predicates :kind

  # Validations
  validates :code, presence: true, uniqueness: true, format: { with: /\A[A-Z0-9]+\z/, message: "must contain only uppercase letters and numbers" }
  validates :kind, presence: true, inclusion: { in: kinds.keys }
  validates :active, inclusion: { in: [ true, false ] }
  validate :has_value_or_percentage
  validate :valid_date_range

  # Callbacks
  before_validation :upcase_code

  # Scopes
  scope :active_now, -> { where(active: true).where("starts_at IS NULL OR starts_at <= ?", Time.current).where("ends_at IS NULL OR ends_at >= ?", Time.current) }
  scope :expired, -> { where("ends_at < ?", Time.current) }

  # Money methods
  def value_in_pesos
    return BigDecimal(0) unless value_cents
    BigDecimal(value_cents) / 100
  end

  def value_in_pesos=(amount)
    self.value_cents = amount ? (BigDecimal(amount.to_s) * 100).to_i : nil
  end

  # State predicates
  def active_now?
    return false unless active?
    return false if starts_at && starts_at > Time.current
    return false if ends_at && ends_at < Time.current
    true
  end

  def expired?
    ends_at && ends_at < Time.current
  end

  # Business logic
  def discount_amount_for(amount_cents)
    return 0 unless active_now?

    if value_cents
      [ value_cents, amount_cents ].min
    elsif percent_off
      (amount_cents * percent_off / 100).to_i
    else
      0
    end
  end

  private

  def upcase_code
    self.code = code&.upcase
  end

  def has_value_or_percentage
    if value_cents.blank? && percent_off.blank?
      errors.add(:base, "must have either a value amount or percentage off")
    end

    if value_cents.present? && percent_off.present?
      errors.add(:base, "cannot have both value amount and percentage off")
    end
  end

  def valid_date_range
    return unless starts_at && ends_at

    if starts_at >= ends_at
      errors.add(:ends_at, "must be after start date")
    end
  end
end
