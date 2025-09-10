# == Schema Information
#
# Table name: payments
#
#  id              :uuid             not null, primary key
#  amount_cents    :integer          not null
#  gateway_payload :jsonb
#  gateway_ref     :string
#  posted_at       :datetime
#  state           :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  loan_id         :uuid             not null
#
# Indexes
#
#  index_payments_on_gateway_ref        (gateway_ref) UNIQUE
#  index_payments_on_loan_id            (loan_id)
#  index_payments_on_loan_id_and_state  (loan_id,state)
#  index_payments_on_posted_at          (posted_at)
#  index_payments_on_state              (state)
#
# Foreign Keys
#
#  fk_rails_...  (loan_id => loans.id)
#
class Payment < ApplicationRecord
  include EnumAliases

  belongs_to :loan

  # Enums
  enum :state, { pending: "pending", cleared: "cleared", failed: "failed" }, prefix: :state

  # Create unprefixed aliases for state predicates (e.g., pending?, cleared?)
  alias_unprefixed_enum_predicates :state

  # Validations
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  validates :state, presence: true, inclusion: { in: states.keys }
  validates :gateway_ref, uniqueness: true, allow_blank: true

  # Callbacks
  after_update :update_loan_balance, if: :saved_change_to_state?

  # Scopes
  scope :successful, -> { where(state: "cleared") }
  scope :recent, -> { order(created_at: :desc) }

  # Money methods
  def amount_in_pesos
    amount_cents / 100.0
  end

  def amount_in_pesos=(amount)
    self.amount_cents = (amount.to_f * 100).to_i
  end

  # State predicates
  def successful?
    cleared?
  end

  def failed_or_pending?
    failed? || pending?
  end

  private

  def update_loan_balance
    return unless cleared?

    # This should be handled by a proper payment reconciliation service
    # For now, just a placeholder to show the concept
    loan.reload
    remaining_balance = loan.total_outstanding_cents - amount_cents

    if remaining_balance <= 0
      loan.update!(
        principal_outstanding_cents: 0,
        interest_accrued_cents: 0,
        penalty_accrued_cents: 0,
        state: "paid"
      )
    else
      # Apply payment to principal first, then interest, then penalties
      remaining_amount = amount_cents

      # Pay down penalties first
      penalty_payment = [ remaining_amount, loan.penalty_accrued_cents ].min
      remaining_amount -= penalty_payment
      loan.penalty_accrued_cents -= penalty_payment

      # Pay down interest next
      if remaining_amount > 0
        interest_payment = [ remaining_amount, loan.interest_accrued_cents ].min
        remaining_amount -= interest_payment
        loan.interest_accrued_cents -= interest_payment
      end

      # Pay down principal last
      if remaining_amount > 0
        principal_payment = [ remaining_amount, loan.principal_outstanding_cents ].min
        loan.principal_outstanding_cents -= principal_payment
      end

      loan.save!
    end
  end
end
