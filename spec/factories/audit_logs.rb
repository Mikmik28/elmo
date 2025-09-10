FactoryBot.define do
  factory :audit_log do
    association :user
    action { "loan.created" }
    association :target, factory: :loan
    changeset { { state: [ nil, "pending" ] } }
    ip { "127.0.0.1" }
    user_agent { "Test/1.0" }
  end
end
