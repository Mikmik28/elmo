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
FactoryBot.define do
  factory :loan do
    user
    amount_cents { 10000_00 } # ₱10,000
    term_days { 30 }
    product { "micro" }
    state { "pending" }
    due_on { Date.current + 30.days }
    principal_outstanding_cents { amount_cents }
    interest_accrued_cents { 0 }
    penalty_accrued_cents { 0 }
    apr { 12.5 }

    trait :micro do
      amount_cents { 5000_00 }
      term_days { 30 }
      product { "micro" }
    end

    trait :extended do
      amount_cents { 15000_00 }
      term_days { 90 }
      product { "extended" }
      due_on { Date.current + 90.days }
    end

    trait :longterm do
      amount_cents { 50000_00 }
      term_days { 270 }
      product { "longterm" }
      due_on { Date.current + 270.days }
    end

    trait :approved do
      state { "approved" }
    end

    trait :disbursed do
      state { "disbursed" }
    end

    trait :paid do
      state { "paid" }
      principal_outstanding_cents { 0 }
      interest_accrued_cents { 0 }
      penalty_accrued_cents { 0 }
    end

    trait :overdue do
      state { "overdue" }
      due_on { Date.current - 5.days }
      penalty_accrued_cents { 250_00 } # ₱250 penalty
    end

    trait :defaulted do
      state { "defaulted" }
      due_on { Date.current - 35.days }
      penalty_accrued_cents { 1500_00 } # ₱1,500 penalty
    end

    trait :with_balance do
      principal_outstanding_cents { amount_cents }
      interest_accrued_cents { (amount_cents * 0.05).to_i }
    end
  end
end
