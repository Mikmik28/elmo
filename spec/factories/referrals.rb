# == Schema Information
#
# Table name: referrals
#
#  id            :uuid             not null, primary key
#  status        :string           default("pending"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  promo_code_id :uuid
#  referee_id    :uuid             not null
#  referrer_id   :uuid             not null
#
# Indexes
#
#  index_referrals_on_promo_code_id               (promo_code_id)
#  index_referrals_on_referee_id                  (referee_id)
#  index_referrals_on_referrer_id                 (referrer_id)
#  index_referrals_on_referrer_id_and_referee_id  (referrer_id,referee_id) UNIQUE
#  index_referrals_on_status                      (status)
#
# Foreign Keys
#
#  fk_rails_...  (promo_code_id => promo_codes.id)
#  fk_rails_...  (referee_id => users.id)
#  fk_rails_...  (referrer_id => users.id)
#
FactoryBot.define do
  factory :referral do
    association :referrer, factory: :user
    association :referee, factory: :user
    status { "pending" }
    promo_code

    trait :rewarded do
      status { "rewarded" }
    end

    trait :with_approved_referee do
      association :referee, factory: [ :user, :kyc_approved ]
    end
  end
end
