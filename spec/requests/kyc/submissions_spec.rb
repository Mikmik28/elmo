# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Kyc::Submissions", type: :request do
  let(:user) { create(:user, :kyc_pending) }
  let(:valid_attributes) do
    {
      kyc: {
        full_name: "Juan Dela Cruz",
        date_of_birth: 25.years.ago.to_date,
        gov_id_type: "drivers_license",
        gov_id_number: "D123-45-678901",
        id_expiry: 1.year.from_now.to_date,
        address_line1: "123 Sample St, Makati City",
        gov_id_image: fixture_file_upload("spec/fixtures/files/sample_id.jpg", "image/jpeg"),
        selfie_image: fixture_file_upload("spec/fixtures/files/sample_selfie.jpg", "image/jpeg")
      }
    }
  end

  describe "GET /kyc" do
    it "shows KYC status page" do
      login_as(user, scope: :user)
      get kyc_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("KYC Verification Status")
    end

    it "shows pending status for new user" do
      login_as(user, scope: :user)
      get kyc_path
      expect(response.body).to include("Verification Pending")
    end
  end

  describe "GET /kyc/new" do
    it "shows KYC form" do
      login_as(user, scope: :user)
      get new_kyc_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Submit KYC Documents")
    end

    it "pre-fills user data" do
      user.update!(full_name: "Test User", phone: "+639123456789")
      login_as(user, scope: :user)
      get new_kyc_path
      expect(response.body).to include("Test User")
      expect(response.body).to include("639123456789")  # Phone gets normalized
    end
  end

  describe "POST /kyc" do
    context "with valid params" do
      it "creates KYC submission successfully" do
        login_as(user, scope: :user)
        post kyc_path, params: valid_attributes

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(kyc_path)
        expect(flash[:notice]).to include("submitted successfully")
      end

      it "attaches files and stores masked payload" do
        login_as(user, scope: :user)
        post kyc_path, params: valid_attributes

        user.reload
        expect(user.kyc_gov_id_image).to be_attached
        expect(user.kyc_selfie_image).to be_attached

        expect(user.kyc_payload).to include(
          "gov_id_type" => "drivers_license",
          "gov_id_number_last4" => "8901",
          "address_line1" => "123 Sample St, Makati City",
          "date_of_birth" => 25.years.ago.to_date.to_s
        )
        expect(user.kyc_payload).not_to include("gov_id_number")
      end

      it "updates user full name" do
        login_as(user, scope: :user)
        expect {
          post kyc_path, params: valid_attributes
        }.to change { user.reload.full_name }.to("Juan Dela Cruz")
      end

      it "publishes KYC submission event" do
        login_as(user, scope: :user)
        expect {
          post kyc_path, params: valid_attributes
        }.to change { OutboxEvent.count }.by(1)

        event = OutboxEvent.last
        expect(event.name).to eq("kyc.submitted.v1")
        expect(event.aggregate_type).to eq("User")
        expect(event.aggregate_id).to eq(user.id)
        expect(event.payload).to include(
          "user_id" => user.id,
          "submission_timestamp" => be_present,
          "document_types" => [ "government_id", "selfie" ]
        )
      end
    end

    context "with invalid params" do
      it "returns unprocessable entity for missing files" do
        login_as(user, scope: :user)
        invalid_params = valid_attributes.dup
        invalid_params[:kyc].delete(:gov_id_image)

        post kyc_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(flash[:alert]).to be_present
      end

      it "returns unprocessable entity for invalid file type" do
        login_as(user, scope: :user)
        invalid_params = valid_attributes.dup
        invalid_params[:kyc][:gov_id_image] = fixture_file_upload("spec/fixtures/files/sample.txt", "text/plain")

        post kyc_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "handles timezone birthdate parsing Manila correctly" do
        login_as(user, scope: :user)

        # Test with a date that could be affected by timezone differences
        Time.use_zone("Asia/Manila") do
          manila_date = Date.current - 25.years

          post kyc_path, params: {
            kyc: valid_attributes[:kyc].merge(date_of_birth: manila_date)
          }

          expect(response).to have_http_status(:redirect)
          expect(user.reload.date_of_birth).to eq(manila_date)
          expect(user.kyc_payload["date_of_birth"]).to eq(manila_date.to_s)
        end
      end
    end
  end

  describe "POST /kyc/simulate_decision" do
    context "in development environment" do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        user.update!(kyc_status: "pending")
      end

      it "approves KYC and publishes event" do
        login_as(user, scope: :user)
        expect {
          post simulate_decision_kyc_path, params: { status: "approved" }
        }.to change { user.reload.kyc_status }.from("pending").to("approved")

        expect(response).to redirect_to(kyc_path)
        expect(flash[:notice]).to include("approved")

        # Check that outbox event was created
        event = OutboxEvent.last
        expect(event.name).to eq("kyc.approved.v1")
        expect(event.aggregate_id).to eq(user.id)
        expect(event.payload["user_id"]).to eq(user.id)
      end

      it "rejects KYC" do
        login_as(user, scope: :user)
        expect {
          post simulate_decision_kyc_path, params: { status: "rejected" }
        }.to change { user.reload.kyc_status }.from("pending").to("rejected")

        expect(response).to redirect_to(kyc_path)
        expect(flash[:alert]).to include("rejected")
      end

      it "returns error for invalid status" do
        login_as(user, scope: :user)
        expect {
          post simulate_decision_kyc_path, params: { status: "invalid" }
        }.to raise_error(ArgumentError)
      end
    end

    context "in non-development environment" do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
      end

      it "returns 404" do
        login_as(user, scope: :user)
        post simulate_decision_kyc_path, params: { status: "approved" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "authorization" do
    it "prevents unauthenticated access" do
      get kyc_path
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
