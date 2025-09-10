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
class Referral < ApplicationRecord
  belongs_to :referrer, class_name: "User"
  belongs_to :referee, class_name: "User"
  belongs_to :promo_code, optional: true

  # Enums
  enum :status, { pending: "pending", rewarded: "rewarded" }, suffix: true

  # Validations
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :referrer_id, uniqueness: { scope: :referee_id, message: "can only refer the same person once" }
  validate :no_self_referral

  # Callbacks
  after_create :create_promo_code_if_needed

  # Scopes
  scope :completed, -> { joins(:referee).where(users: { kyc_status: "approved" }) }
  scope :eligible_for_reward, -> { pending_status.completed }

  # Business logic
  def eligible_for_reward?
    pending_status? && referee.kyc_approved?
  end

  def reward!
    return false unless eligible_for_reward?

    transaction do
      update!(status: "rewarded")
      # Here you would typically create credits or apply rewards
      # This could be handled by a service or event
    end
  end

  private

  def no_self_referral
    if referrer_id == referee_id
      errors.add(:referee, "cannot refer yourself")
    end
  end

  def create_promo_code_if_needed
    return if promo_code.present?

    # Create a referral promo code for the referrer
    code = PromoCode.create!(
      code: "REF#{SecureRandom.alphanumeric(6).upcase}",
      kind: "referral",
      value_cents: 50_00, # ₱50 referral bonus
      active: true
    )

    update!(promo_code: code)
  end
end
