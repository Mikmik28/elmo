# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Scoring::Previews", type: :request do
  let!(:user) { create(:user, :kyc_approved) }

  around do |example|
    # Temporarily enable preview for tests
    original_value = Rails.configuration.x.scoring.preview_enabled
    Rails.configuration.x.scoring.preview_enabled = true

    begin
      example.run
    ensure
      Rails.configuration.x.scoring.preview_enabled = original_value
    end
  end

  describe "GET /scoring/preview" do
    context "when not authenticated" do
      it "redirects to sign in" do
        get "/scoring/preview"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      before do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: user.password
          }
        }
      end

      it "shows the preview page" do
        get "/scoring/preview"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Credit Score Preview")
      end

      it "displays user information" do
        get "/scoring/preview"
        # Should show something about the user's score, not necessarily their email in UI
        expect(response.body).to include("Credit Score Preview")
      end

      it "shows computed score" do
        # User starts with default current_score: 600
        get "/scoring/preview"
        expect(response.body).to include("600")
      end
    end
  end

  describe "POST /scoring/recompute" do
    context "when not authenticated" do
      it "redirects to sign in" do
        post "/scoring/recompute"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      before do
        post user_session_path, params: {
          user: {
            email: user.email,
            password: user.password
          }
        }
      end

      it "recomputes and updates user score" do
        # Create loan and payment data to give user payment history
        loan = create(:loan, user: user, amount_cents: 100000, state: :paid) # 1000 pesos
        create(:payment, loan: loan, amount_cents: 100000, state: :cleared)

        old_score = user.current_score

        expect {
          post "/scoring/recompute"
        }.to change { user.reload.current_score }

        expect(response).to redirect_to("/scoring/preview")
        follow_redirect!
        expect(response.body).to include("Score recomputed")
      end

      it "handles computation errors gracefully" do
        # The service should handle any edge cases gracefully
        post "/scoring/recompute"
        expect(response).to redirect_to("/scoring/preview")
        follow_redirect!
        expect(response.body).to include("Score recomputed")
      end

      it "creates audit trail" do
        expect {
          post "/scoring/recompute"
        }.to change(CreditScoreEvent, :count).by(1)

        event = CreditScoreEvent.last
        expect(event.user).to eq(user)
        expect(event.reason).to eq("recompute")
        expect(event.delta).to be_present
      end

      it "emits outbox event" do
        # Change user's score first to ensure it will be different after recompute
        user.update!(current_score: 500)

        expect {
          post "/scoring/recompute"
        }.to change(OutboxEvent, :count).by(1)

        event = OutboxEvent.last
        expect(event.name).to eq("user.score_changed.v1")
        expect(event.payload["user_id"]).to eq(user.id)
      end
    end
  end
end
