# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::KycReviews", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:pending_kyc_user) { create(:user, :kyc_pending_with_data) }

  describe "GET /admin/kyc_reviews" do
    context "when user is admin" do
      before { login_as(admin_user, scope: :user) }

      it "shows pending KYC reviews" do
        pending_kyc_user # Create the user
        get admin_kyc_reviews_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("KYC Reviews")
        expect(response.body).to include(pending_kyc_user.full_name)
      end

      it "shows empty state when no pending reviews" do
        get admin_kyc_reviews_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("No pending KYC reviews")
      end
    end

    context "when user is not admin" do
      before { login_as(regular_user, scope: :user) }

      it "denies access" do
        get admin_kyc_reviews_path
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "GET /admin/kyc_reviews/:id" do
    context "when user is admin" do
      before { login_as(admin_user, scope: :user) }

      it "shows KYC review details" do
        get admin_kyc_review_path(pending_kyc_user)

        expect(response).to have_http_status(:success)
        expect(response.body).to include(pending_kyc_user.full_name)
        expect(response.body).to include("Approve KYC")
        expect(response.body).to include("Reject KYC")
      end
    end
  end

  describe "PATCH /admin/kyc_reviews/:id/approve" do
    context "when user is admin" do
      before { login_as(admin_user, scope: :user) }

      it "approves KYC and publishes event" do
        expect {
          patch approve_admin_kyc_review_path(pending_kyc_user)
        }.to change { pending_kyc_user.reload.kyc_status }.from("pending").to("approved")

        expect(response).to redirect_to(admin_kyc_reviews_path)
        expect(flash[:notice]).to include("approved")

        # Check that outbox event was created
        event = OutboxEvent.last
        expect(event.name).to eq("kyc.approved.v1")
        expect(event.payload["approved_by"]).to eq(admin_user.id)
      end
    end
  end

  describe "PATCH /admin/kyc_reviews/:id/reject" do
    context "when user is admin" do
      before { login_as(admin_user, scope: :user) }

      it "rejects KYC" do
        expect {
          patch reject_admin_kyc_review_path(pending_kyc_user)
        }.to change { pending_kyc_user.reload.kyc_status }.from("pending").to("rejected")

        expect(response).to redirect_to(admin_kyc_reviews_path)
        expect(flash[:alert]).to include("rejected")
      end
    end
  end
end
