# == Schema Information
#
# Table name: credit_score_events
#
#  id         :uuid             not null, primary key
#  delta      :integer          not null
#  meta       :jsonb
#  reason     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_credit_score_events_on_created_at              (created_at)
#  index_credit_score_events_on_reason                  (reason)
#  index_credit_score_events_on_user_id                 (user_id)
#  index_credit_score_events_on_user_id_and_created_at  (user_id,created_at)
#  index_credit_score_events_on_user_id_and_reason      (user_id,reason)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :credit_score_event do
    user
    reason { "on_time_payment" }
    delta { 20 }
    meta { { loan_id: "uuid-example", payment_amount: 10000 } }

    trait :positive do
      delta { 25 }
      reason { "on_time_payment" }
    end

    trait :negative do
      delta { -30 }
      reason { "overdue" }
    end

    trait :kyc_bonus do
      delta { 50 }
      reason { "kyc_bonus" }
    end

    trait :utilization_penalty do
      delta { -15 }
      reason { "utilization" }
    end

    trait :default_penalty do
      delta { -100 }
      reason { "default" }
    end
  end
end
