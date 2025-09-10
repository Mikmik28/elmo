# == Schema Information
#
# Table name: audit_logs
#
#  id          :uuid             not null, primary key
#  action      :string           not null
#  changeset   :jsonb
#  ip          :string
#  target_type :string
#  user_agent  :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  target_id   :uuid
#  user_id     :uuid             not null
#
# Indexes
#
#  index_audit_logs_on_action                     (action)
#  index_audit_logs_on_created_at                 (created_at)
#  index_audit_logs_on_target_type                (target_type)
#  index_audit_logs_on_target_type_and_target_id  (target_type,target_id)
#  index_audit_logs_on_user_id                    (user_id)
#  index_audit_logs_on_user_id_and_action         (user_id,action)
#  index_audit_logs_on_user_id_and_created_at     (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
