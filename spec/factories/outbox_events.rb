# == Schema Information
#
# Table name: outbox_events
#
#  id             :uuid             not null, primary key
#  aggregate_type :string           not null
#  attempts       :integer          default(0), not null
#  headers        :jsonb
#  name           :string           not null
#  payload        :jsonb
#  processed      :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  aggregate_id   :uuid             not null
#
# Indexes
#
#  index_outbox_events_on_aggregate_type_and_aggregate_id  (aggregate_type,aggregate_id)
#  index_outbox_events_on_created_at                       (created_at)
#  index_outbox_events_on_name                             (name)
#  index_outbox_events_on_processed                        (processed)
#  index_outbox_events_on_processed_and_created_at         (processed,created_at)
#
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
