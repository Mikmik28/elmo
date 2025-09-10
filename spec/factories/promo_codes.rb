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
FactoryBot.define do
  factory :promo_code do
    sequence(:code) { |n| "PROMO#{n.to_s.rjust(3, '0')}" }
    kind { "discount" }
    value_cents { 500_00 } # ₱500
    active { true }
    starts_at { Time.current - 1.day }
    ends_at { Time.current + 30.days }

    trait :referral do
      kind { "referral" }
      value_cents { 100_00 } # ₱100 referral bonus
    end

    trait :percentage do
      kind { "discount" }
      value_cents { nil }
      percent_off { 10.0 } # 10% off
    end

    trait :expired do
      starts_at { Time.current - 10.days }
      ends_at { Time.current - 1.day }
    end

    trait :inactive do
      active { false }
    end

    trait :future do
      starts_at { Time.current + 1.day }
      ends_at { Time.current + 30.days }
    end
  end
end
