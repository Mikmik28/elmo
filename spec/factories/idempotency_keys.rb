# == Schema Information
#
# Table name: idempotency_keys
#
#  id            :uuid             not null, primary key
#  key           :string           not null
#  resource_type :string
#  scope         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  resource_id   :uuid
#
# Indexes
#
#  index_idempotency_keys_on_key_and_scope                  (key,scope) UNIQUE
#  index_idempotency_keys_on_resource_type_and_resource_id  (resource_type,resource_id)
#
FactoryBot.define do
  factory :idempotency_key do
    key { "idem-#{SecureRandom.uuid}" }
    scope { "payments/webhook" }
    association :resource, factory: :loan
  end
end
