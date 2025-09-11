# frozen_string_literal: true

require "rails_helper"

RSpec.describe Accounts::Services::CreditScoringService, type: :service do
  let(:user) { create(:user, :kyc_approved, credit_limit_cents: 10000_00, created_at: 2.years.ago) }
  let(:service) { described_class.new(user) }

  before do
    # Ensure SOLID_QUEUE_INLINE for deterministic tests
    ENV["SOLID_QUEUE_INLINE"] = "1"
  end

  describe "#compute!" do
    context "with default user (good profile)" do
      it "returns a score within bounds" do
        score = service.compute!
        expect(score).to be_between(300, 950)
      end

      it "clamps score to 300..950 bounds" do
        # Test minimum bound
        user.update!(current_score: 350)
        score = service.compute!(persist: true)
        expect(score).to be >= 300
        expect(score).to be <= 950
      end
    end

    context "with persist: true" do
      it "updates user current_score" do
        old_score = user.current_score
        new_score = service.compute!(persist: true)

        expect(user.reload.current_score).to eq(new_score)
        expect(new_score).not_to eq(old_score) # Should be different from starting score
      end

      it "creates credit_score_event when score changes" do
        user.update!(current_score: 500)

        expect {
          service.compute!(persist: true)
        }.to change { user.credit_score_events.count }.by(1)

        event = user.credit_score_events.last
        expect(event.reason).to eq("recompute")
        expect(event.meta).to include("scoring_components")
      end

      it "does not create event when score unchanged" do
        # First computation to establish baseline
        score = service.compute!(persist: true)
        user.reload

        # Reset event count
        initial_event_count = user.credit_score_events.count

        # Second computation should not create new event if score is same
        expect {
          service.compute!(persist: true)
        }.not_to change { user.credit_score_events.count }.from(initial_event_count)
      end
    end

    context "with emit_event: true" do
      it "publishes outbox event when score changes" do
        user.update!(current_score: 500)

        expect {
          service.compute!(emit_event: true)
        }.to change { OutboxEvent.count }.by(1)

        event = OutboxEvent.last
        expect(event.name).to eq("user.score_changed.v1")
        expect(event.payload).to include(
          "user_id" => user.id,
          "old_score" => 500,
          "new_score" => kind_of(Integer)
        )
      end

      it "does not emit event when score unchanged" do
        # Get current score
        current_score = service.compute!
        user.update!(current_score: current_score)

        expect {
          service.compute!(emit_event: true)
        }.not_to change { OutboxEvent.count }
      end
    end

    context "with high utilization (penalizes score)" do
      before do
        # Create loans that use most of credit limit
        create(:loan, :disbursed, user: user, principal_outstanding_cents: 9000_00)
      end

      it "decreases score due to high utilization" do
        low_util_user = create(:user, :kyc_approved, credit_limit_cents: 10000_00, created_at: 2.years.ago)
        high_util_score = service.compute!
        low_util_score = described_class.new(low_util_user).compute!

        expect(high_util_score).to be < low_util_score
      end
    end

    context "with recent overdue loans (penalizes behavior)" do
      before do
        # Create recent overdue loan
        create(:loan, :overdue, user: user, updated_at: 30.days.ago)
      end

      it "significantly penalizes score" do
        clean_user = create(:user, :kyc_approved, credit_limit_cents: 10000_00, created_at: 2.years.ago)
        overdue_score = service.compute!
        clean_score = described_class.new(clean_user).compute!

        expect(overdue_score).to be < clean_score
      end
    end

    context "with good payment history (increases score)" do
      before do
        # Create historical on-time payments
        3.times do |i|
          loan = create(:loan, :disbursed, user: user, due_on: (6 + i).months.ago, created_at: (7 + i).months.ago)
          create(:payment, :cleared, loan: loan, created_at: (6 + i).months.ago - 1.day)
          loan.update!(state: "paid", principal_outstanding_cents: 0)
        end
      end

      it "increases score due to good payment history" do
        no_history_user = create(:user, :kyc_approved, credit_limit_cents: 10000_00, created_at: 2.years.ago)
        good_history_score = service.compute!
        no_history_score = described_class.new(no_history_user).compute!

        expect(good_history_score).to be > no_history_score
      end
    end

    context "with KYC not approved" do
      let(:user) { create(:user, :kyc_pending, credit_limit_cents: 10000_00, created_at: 2.years.ago) }

      it "penalizes score" do
        kyc_approved_user = create(:user, :kyc_approved, credit_limit_cents: 10000_00, created_at: 2.years.ago)
        kyc_pending_score = service.compute!
        kyc_approved_score = described_class.new(kyc_approved_user).compute!

        expect(kyc_pending_score).to be < kyc_approved_score
      end
    end

    context "with new account (tenure penalty)" do
      let(:user) { create(:user, :kyc_approved, credit_limit_cents: 10000_00, created_at: 3.days.ago) }

      it "penalizes score for short tenure" do
        old_user = create(:user, :kyc_approved, credit_limit_cents: 10000_00, created_at: 2.years.ago)
        new_score = service.compute!
        old_score = described_class.new(old_user).compute!

        expect(new_score).to be < old_score
      end
    end
  end

  describe "#breakdown" do
    it "returns detailed component breakdown" do
      breakdown = service.breakdown

      expect(breakdown).to include(:payment_history, :utilization, :tenure, :behavior, :kyc)

      breakdown.each do |component, data|
        expect(data).to include(:raw_value, :normalized, :weight, :contribution)
        expect(data[:normalized]).to be_between(-100, 100)
        expect(data[:weight]).to be > 0
      end
    end

    it "has weights that sum to 1.0" do
      breakdown = service.breakdown
      total_weight = breakdown.values.sum { |v| v[:weight] }
      expect(total_weight).to be_within(0.001).of(1.0)
    end
  end

  describe "idempotency" do
    it "returns same score for same inputs" do
      score1 = service.compute!
      score2 = service.compute!

      expect(score1).to eq(score2)
    end
  end

  describe "concurrency safety" do
    it "handles parallel calls deterministically" do
      scores = Array.new(3) { Thread.new { service.compute! } }.map(&:value)

      expect(scores.uniq.size).to eq(1), "All parallel calls should return same score"
    end
  end
end
