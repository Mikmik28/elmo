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
class IdempotencyKey < ApplicationRecord
  belongs_to :resource, polymorphic: true, optional: true

  # Validations
  validates :key, presence: true
  validates :scope, presence: true
  validates :key, uniqueness: { scope: :scope }

  # Class methods
  def self.lock_or_raise!(key:, scope:, resource: nil)
    existing = find_by(key: key, scope: scope)

    if existing
      if existing.resource != resource
        raise StandardError, "Idempotency key '#{key}' already used for different resource"
      end
      return existing
    end

    create!(
      key: key,
      scope: scope,
      resource: resource
    )
  end

  def self.exists_for?(key:, scope:)
    exists?(key: key, scope: scope)
  end
end
