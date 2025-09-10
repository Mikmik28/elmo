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
class OutboxEvent < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :aggregate_id, presence: true
  validates :aggregate_type, presence: true
  validates :processed, inclusion: { in: [ true, false ] }
  validates :attempts, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :unprocessed, -> { where(processed: false) }
  scope :processed, -> { where(processed: true) }
  scope :failed, -> { where(processed: false).where("attempts >= ?", 10) }
  scope :ready_for_retry, -> { unprocessed.where("attempts < ?", 10) }

  # Business logic
  def mark_as_processed!
    update!(processed: true)
  end

  def increment_attempts!
    increment!(:attempts)
  end

  def dead_letter?
    attempts >= 10
  end

  def ready_for_retry?
    !processed? && !dead_letter?
  end

  # Class methods
  def self.publish!(name:, aggregate:, payload: {}, headers: {})
    create!(
      name: name,
      aggregate_id: aggregate.id,
      aggregate_type: aggregate.class.name,
      payload: payload,
      headers: headers.merge(
        published_at: Time.current.iso8601,
        correlation_id: headers[:correlation_id] || SecureRandom.uuid
      )
    )
  end
end
