FactoryBot.define do
  factory :idempotency_key do
    key { "idem-#{SecureRandom.uuid}" }
    scope { "payments/webhook" }
    association :resource, factory: :loan
  end
end
