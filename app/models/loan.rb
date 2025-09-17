# == Schema Information
#
# Table name: loans
#
#  id                          :uuid             not null, primary key
#  amount_cents                :integer          not null
#  apr                         :decimal(10, 4)
#  due_on                      :date
#  interest_accrued_cents      :integer          default(0), not null
#  penalty_accrued_cents       :integer          default(0), not null
#  principal_outstanding_cents :integer          default(0), not null
#  product                     :string           not null
#  state                       :string           default("pending"), not null
#  term_days                   :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  user_id                     :uuid             not null
#
# Indexes
#
#  index_loans_on_due_on             (due_on)
#  index_loans_on_state              (state)
#  index_loans_on_state_and_due_on   (state,due_on)
#  index_loans_on_user_id            (user_id)
#  index_loans_on_user_id_and_state  (user_id,state)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Loan < ApplicationRecord
  include EnumAliases

  belongs_to :user
  has_many :payments, dependent: :destroy

  # Enums
  enum :product, { micro: "micro", extended: "extended", longterm: "longterm" }, suffix: true
  enum :state, {
    pending: "pending",
    approved: "approved",
    rejected: "rejected",
    disbursed: "disbursed",
    paid: "paid",
    overdue: "overdue",
    defaulted: "defaulted"
  }, prefix: :state

  # Create unprefixed aliases for state predicates (e.g., pending?, paid?)
  alias_unprefixed_enum_predicates :state

  # Product-specific amount limits (in cents)
  PRODUCT_AMOUNT_LIMITS = {
    "micro" => { min: 1_000_00, max: 15_000_00 },     # ₱1,000 - ₱15,000
    "extended" => { min: 10_000_00, max: 35_000_00 }, # ₱10,000 - ₱35,000
    "longterm" => { min: 25_000_00, max: 75_000_00 }  # ₱25,000 - ₱75,000
  }.freeze

  # Validations
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :term_days, presence: true, numericality: { greater_than: 0 }
  validates :product, presence: true, inclusion: { in: products.keys }
  validates :state, presence: true, inclusion: { in: states.keys }
  validates :principal_outstanding_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :interest_accrued_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :penalty_accrued_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :longterm_term_validation
  validate :due_date_after_creation
  validate :valid_term_days_for_product
  validate :amount_within_product_limits

  # Callbacks
  before_validation :auto_assign_product_from_term, on: :create
  before_validation :set_principal_outstanding, on: :create
  before_validation :calculate_due_date, on: :create

  # Scopes
  scope :active, -> { where(state: %w[disbursed overdue]) }
  scope :overdue_today, -> { where(state: "disbursed").where("due_on < ?", Time.zone.today) }
  scope :due_soon, ->(days = 3) { where(state: "disbursed").where(due_on: Time.zone.today..Time.zone.today + days.days) }
  scope :on_time, -> { where(state: "paid").joins(:payments).where("payments.created_at <= loans.due_on") }
  scope :overdue_recent, ->(days = 90) { where(state: %w[overdue defaulted]).where("updated_at >= ?", days.days.ago) }

  # Money methods
  def amount_in_pesos
    BigDecimal(amount_cents) / 100
  end

  def amount_in_pesos=(amount)
    self.amount_cents = (BigDecimal(amount.to_s) * 100).to_i
  end

  def principal_outstanding_in_pesos
    BigDecimal(principal_outstanding_cents) / 100
  end

  def interest_accrued_in_pesos
    BigDecimal(interest_accrued_cents) / 100
  end

  def penalty_accrued_in_pesos
    BigDecimal(penalty_accrued_cents) / 100
  end

  def total_outstanding_cents
    principal_outstanding_cents + interest_accrued_cents + penalty_accrued_cents
  end

  def total_outstanding_in_pesos
    BigDecimal(total_outstanding_cents) / 100
  end

  # Alias for outstanding_balance_cents to match interface requirement
  alias_method :outstanding_balance_cents, :total_outstanding_cents

  # State predicates
  def overdue?
    # Manila timezone-aware overdue check
    disbursed? && due_on && due_on < Time.zone.today && total_outstanding_cents > 0
  end

  def defaulted_threshold_reached?
    overdue? && (Time.zone.today - due_on).to_i > 30
  end

  # Business logic
  def days_overdue
    return 0 unless overdue?
    (Time.zone.today - due_on).to_i
  end

  def can_be_approved?
    pending? && user.kyc_approved? && !user.has_overdue_loans?
  end

  private

  def auto_assign_product_from_term
    return if product.present? || term_days.blank?

    begin
      self.product = Loans::Services::TermProductSelector.for(term_days)
    rescue Loans::Services::TermProductSelector::InvalidTermError
      # Let validation catch the invalid term_days
      self.product = nil
    end
  end

  def longterm_term_validation
    return unless longterm_product?

    unless [ 270, 365 ].include?(term_days)
      errors.add(:term_days, "must be 270 or 365 days for longterm loans")
    end
  end

  def valid_term_days_for_product
    return if term_days.blank?

    begin
      expected_product = Loans::Services::TermProductSelector.for(term_days)
      if product.present? && product != expected_product
        errors.add(:term_days, "invalid for product type #{product}")
      end
    rescue Loans::Services::TermProductSelector::InvalidTermError => e
      errors.add(:term_days, e.message.split(": ").last)
    end
  end

  def due_date_after_creation
    return unless due_on && created_at
    return if persisted? && (state_overdue? || state_defaulted? || state_paid?)

    if due_on <= Time.zone.today
      errors.add(:due_on, "must be in the future")
    end
  end

  def set_principal_outstanding
    self.principal_outstanding_cents = amount_cents if amount_cents.present?
  end

  def calculate_due_date
    return unless term_days

    # Use Manila timezone (Time.zone.today) while storing in UTC for database
    self.due_on = Time.zone.today + term_days.days
  end

  def amount_within_product_limits
    return if amount_cents.blank? || product.blank?

    limits = PRODUCT_AMOUNT_LIMITS[product]
    return unless limits

    if amount_cents < limits[:min]
      min_pesos = BigDecimal(limits[:min]) / 100
      errors.add(:amount_cents, "must be at least ₱#{min_pesos.to_i} for #{product} loans")
    elsif amount_cents > limits[:max]
      max_pesos = BigDecimal(limits[:max]) / 100
      errors.add(:amount_cents, "must not exceed ₱#{max_pesos.to_i} for #{product} loans")
    end
  end
end
