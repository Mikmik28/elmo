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
class CreditScoreEvent < ApplicationRecord
  belongs_to :user

  # Enums
  enum :reason, {
    on_time_payment: "on_time_payment",
    overdue: "overdue",
    utilization: "utilization",
    kyc_bonus: "kyc_bonus",
    default: "default",
    recompute: "recompute"
  }, suffix: true

  # Validations
  validates :reason, presence: true, inclusion: { in: reasons.keys }
  validates :delta, presence: true, numericality: { other_than: 0 }

  # Callbacks
  after_create_commit :sync_user_score, if: -> { Rails.configuration.x.scoring.legacy_delta_mode }

  # Scopes
  scope :positive, -> { where("delta > 0") }
  scope :negative, -> { where("delta < 0") }
  scope :recent, ->(days = 30) { where("created_at >= ?", days.days.ago) }

  # Class methods
  def self.record_event!(user:, reason:, delta:, meta: {})
    create!(
      user: user,
      reason: reason,
      delta: delta,
      meta: meta
    )
  end

  private

  def sync_user_score
    user.with_lock do
      new_score = [ 900, [ 300, user.current_score + delta ].max ].min
      user.update!(current_score: new_score)
    end
  end
end
