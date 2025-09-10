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
FactoryBot.define do
  factory :payment do
    loan
    amount_cents { 5000_00 } # ₱5,000
    state { "pending" }
    gateway_ref { "gw_#{SecureRandom.alphanumeric(10)}" }
    posted_at { Time.current }
    gateway_payload { { status: "success", transaction_id: gateway_ref } }

    trait :cleared do
      state { "cleared" }
    end

    trait :failed do
      state { "failed" }
      gateway_payload { { status: "failed", error: "Insufficient funds" } }
    end

    trait :partial do
      amount_cents { loan.total_outstanding_cents / 2 }
    end

    trait :full do
      amount_cents { loan.total_outstanding_cents }
    end
  end
end
