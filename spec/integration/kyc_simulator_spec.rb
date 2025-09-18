# frozen_string_literal: true

require "rails_helper"

RSpec.describe "KYC Simulator Integration", type: :request do
  let(:user) { create(:user, kyc_status: "pending") }

  before do
    login_as(user, scope: :user)
  end

  describe "KYC approval event emission" do
    context "in development environment" do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it "publishes outbox event when KYC is approved" do
        expect {
          post simulate_decision_kyc_path, params: { status: "approved" }
        }.to change { OutboxEvent.count }.by(1)

        event = OutboxEvent.last
        expect(event.name).to eq("user.kyc_approved.v1")
        expect(event.aggregate_type).to eq("User")
        expect(event.aggregate_id).to eq(user.id)
        expect(event.payload).to include(
          "user_id" => user.id,
          "approval_timestamp" => be_present,
          "previous_status" => "pending"
        )
        expect(event.processed).to be false
      end

      it "does not publish event when KYC is rejected" do
        expect {
          post simulate_decision_kyc_path, params: { status: "rejected" }
        }.not_to change { OutboxEvent.count }
      end

      it "updates user KYC status on approval" do
        expect {
          post simulate_decision_kyc_path, params: { status: "approved" }
        }.to change { user.reload.kyc_status }.from("pending").to("approved")
      end

      it "updates user KYC status on rejection" do
        expect {
          post simulate_decision_kyc_path, params: { status: "rejected" }
        }.to change { user.reload.kyc_status }.from("pending").to("rejected")
      end
    end

    context "in non-development environment" do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
      end

      it "does not allow simulator access" do
        post simulate_decision_kyc_path, params: { status: "approved" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "event payload structure" do
    before do
      allow(Rails.env).to receive(:development?).and_return(true)
    end

    it "includes required event metadata" do
      post simulate_decision_kyc_path, params: { status: "approved" }

      event = OutboxEvent.last
      expect(event.headers).to include("published_at")
      expect(event.headers).to include("correlation_id")
      expect(event.headers["correlation_id"]).to be_present
    end

    it "includes user context in payload" do
      post simulate_decision_kyc_path, params: { status: "approved" }

      event = OutboxEvent.last
      expect(event.payload["user_id"]).to eq(user.id)
    end
  end
end
