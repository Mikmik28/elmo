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
class AuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :target, polymorphic: true, optional: true

  # Validations
  validates :action, presence: true
  validates :user, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_target, ->(target) { where(target: target) }
  scope :for_action, ->(action) { where(action: action) }
  scope :for_user, ->(user) { where(user: user) }

  # Class methods
  def self.log!(user:, action:, target: nil, changeset: {}, ip: nil, user_agent: nil)
    create!(
      user: user,
      action: action,
      target: target,
      changeset: changeset,
      ip: ip,
      user_agent: user_agent
    )
  end

  # Instance methods
  def target_display
    return "N/A" unless target
    "#{target_type} ##{target_id}"
  end

  def changes_summary
    return "No changes" if changeset.blank?

    changeset.map do |field, (old_val, new_val)|
      "#{field}: #{old_val} → #{new_val}"
    end.join(", ")
  end
end
