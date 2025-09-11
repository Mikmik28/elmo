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
require 'rails_helper'

RSpec.describe CreditScoreEvent, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:reason) }
    it { should validate_presence_of(:delta) }
    it 'validates delta cannot be zero' do
      event = build(:credit_score_event, delta: 0)
      expect(event).not_to be_valid
      expect(event.errors[:delta]).to include('must be other than 0')
    end
  end

  describe 'enums' do
    it { should define_enum_for(:reason).with_values(
      on_time_payment: 'on_time_payment',
      overdue: 'overdue',
      utilization: 'utilization',
      kyc_bonus: 'kyc_bonus',
      default: 'default',
      recompute: 'recompute'
    ).backed_by_column_of_type(:string).with_suffix }
  end

  describe 'callbacks' do
    let(:user) { create(:user, current_score: 600) }

    context 'when legacy_delta_mode is enabled' do
      around do |example|
        original_value = Rails.configuration.x.scoring.legacy_delta_mode
        Rails.configuration.x.scoring.legacy_delta_mode = true

        begin
          example.run
        ensure
          Rails.configuration.x.scoring.legacy_delta_mode = original_value
        end
      end

      it 'updates user credit score on creation' do
        expect {
          CreditScoreEvent.create!(user: user, reason: 'on_time_payment', delta: 25)
          user.reload
        }.to change { user.current_score }.from(600).to(625)
      end

      it 'enforces credit score bounds (300-950)' do
        user = create(:user, current_score: 800)

        # Try to exceed upper bound
        CreditScoreEvent.create!(user: user, reason: 'kyc_bonus', delta: 200)

        user.reload
        expect(user.current_score).to eq(950) # Cannot go above 950
      end
    end

    context 'when legacy_delta_mode is disabled (default)' do
      it 'does not automatically update user credit score' do
        expect {
          CreditScoreEvent.create!(user: user, reason: 'on_time_payment', delta: 25)
          user.reload
        }.not_to change { user.current_score }
      end

      it 'still creates the event record' do
        expect {
          CreditScoreEvent.create!(user: user, reason: 'on_time_payment', delta: 25)
        }.to change(CreditScoreEvent, :count).by(1)
      end
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:positive_event) { create(:credit_score_event, user: user, delta: 20) }
    let!(:negative_event) { create(:credit_score_event, user: user, delta: -15) }
    let!(:old_event) { create(:credit_score_event, user: user, delta: 10, created_at: 35.days.ago) }

    it 'positive scope returns events with positive delta' do
      expect(CreditScoreEvent.positive).to include(positive_event)
      expect(CreditScoreEvent.positive).not_to include(negative_event)
    end

    it 'negative scope returns events with negative delta' do
      expect(CreditScoreEvent.negative).to include(negative_event)
      expect(CreditScoreEvent.negative).not_to include(positive_event)
    end

    it 'recent scope returns events within specified days' do
      expect(CreditScoreEvent.recent(30)).to contain_exactly(positive_event, negative_event)
    end
  end

  describe '.record_event!' do
    let(:user) { create(:user) }

    it 'creates a credit score event' do
      expect {
        CreditScoreEvent.record_event!(
          user: user,
          reason: 'on_time_payment',
          delta: 20,
          meta: { loan_id: 'test-loan-id' }
        )
      }.to change(CreditScoreEvent, :count).by(1)
    end

    context 'when legacy_delta_mode is enabled' do
      around do |example|
        original_value = Rails.configuration.x.scoring.legacy_delta_mode
        Rails.configuration.x.scoring.legacy_delta_mode = true

        begin
          example.run
        ensure
          Rails.configuration.x.scoring.legacy_delta_mode = original_value
        end
      end

      it 'updates the user credit score' do
        expect {
          CreditScoreEvent.record_event!(user: user, reason: 'kyc_bonus', delta: 50)
          user.reload
        }.to change { user.current_score }.by(50)
      end
    end

    context 'when legacy_delta_mode is disabled (default)' do
      it 'does not update the user credit score automatically' do
        expect {
          CreditScoreEvent.record_event!(user: user, reason: 'kyc_bonus', delta: 50)
          user.reload
        }.not_to change { user.current_score }
      end
    end
  end
end
