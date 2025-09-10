FactoryBot.define do
  factory :outbox_event do
    name { "loan.created.v1" }
    aggregate_id { SecureRandom.uuid }
    aggregate_type { "Loan" }
    payload { { user_id: SecureRandom.uuid, amount_cents: 10000 } }
    headers { { correlation_id: SecureRandom.uuid } }
    processed { false }
    attempts { 0 }
  end
end
