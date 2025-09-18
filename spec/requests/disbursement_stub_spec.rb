# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Disbursement Stub API", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, kyc_status: "approved", otp_required_for_login: false) }
  let(:admin_user) { create(:user, role: "admin", otp_required_for_login: false) }
  let(:other_user) { create(:user, kyc_status: "approved", otp_required_for_login: false) }
  
  let(:approved_loan) do
    create(:loan, 
           user: user, 
           state: "approved", 
           amount_cents: 1000_00, 
           term_days: 30,
           product: "micro")
  end

  before do
    # Ensure inline queue processing for tests
    ENV['SOLID_QUEUE_INLINE'] = '1'
  end

  describe "POST /api/loans/:loan_id/disburse" do
    context "happy path disbursement" do
      it "successfully disburses approved loan with required events and payment" do
        login_as(user, scope: :user)
        
        # Freeze time for deterministic gateway reference
        travel_to Time.zone.parse("2025-01-15 10:00:00") do
          expect {
            post "/api/loans/#{approved_loan.id}/disburse",
                 headers: { "Idempotency-Key" => "test-key-1" }
          }.to change { approved_loan.reload.state }.from("approved").to("disbursed")
             .and change { Payment.count }.by(1)
             .and change { OutboxEvent.count }.by(2)

          expect(response).to have_http_status(:created)
          
          # Reload loan to verify state change
          approved_loan.reload
          expect(approved_loan.state).to eq("disbursed")
          
          expect(Payment.count).to eq(1)
          expect(OutboxEvent.count).to eq(2)
          
          json_response = JSON.parse(response.body)
          expect(json_response["loan"]["id"]).to eq(approved_loan.id)
          expect(json_response["loan"]["state"]).to eq("disbursed")
          
          # Verify payment creation
          payment = approved_loan.payments.last
          expect(payment.amount_cents).to eq(1000_00)
          expect(payment.state).to eq("pending")
          expect(payment.gateway_ref).to match(/^stub-#{user.id}-\d+$/)
          expect(json_response["loan"]["payment"]["gateway_ref"]).to eq(payment.gateway_ref)

          # Verify outbox events
          events = OutboxEvent.where(aggregate_id: approved_loan.id, aggregate_type: "Loan").order(:created_at)
          expect(events.count).to eq(2)
          
          requested_event = events.find { |e| e.name == "loan.disbursement_requested.v1" }
          disbursed_event = events.find { |e| e.name == "loan.disbursed.v1" }
          
          expect(requested_event).to be_present
          expect(requested_event.payload["loan_id"]).to eq(approved_loan.id)
          expect(requested_event.payload["amount_cents"]).to eq(100000)
          
          expect(disbursed_event).to be_present
          expect(disbursed_event.payload["loan_id"]).to eq(approved_loan.id)
          expect(disbursed_event.payload["amount_cents"]).to eq(100000)
          expect(disbursed_event.headers["gateway_ref"]).to eq(payment.gateway_ref)

          expect(json_response["loan"]["events"]).to contain_exactly(
            "loan.disbursement_requested.v1", 
            "loan.disbursed.v1"
          )
        end
      end
    end

    context "idempotency enforcement" do
      it "prevents duplicate disbursements with same idempotency key" do
        login_as(user, scope: :user)
        
        # First request
        travel_to Time.zone.parse("2025-01-15 10:00:00") do
          post "/api/loans/#{approved_loan.id}/disburse",
               headers: { "Idempotency-Key" => "duplicate-key" }
          
          expect(response).to have_http_status(:created)
          first_response = JSON.parse(response.body)
          
          # Second request with same key
          expect {
            post "/api/loans/#{approved_loan.id}/disburse",
                 headers: { "Idempotency-Key" => "duplicate-key" }
          }.to_not change { Payment.count }
          
          expect {
            post "/api/loans/#{approved_loan.id}/disburse",
                 headers: { "Idempotency-Key" => "duplicate-key" }
          }.to_not change { OutboxEvent.count }

          expect(response).to have_http_status(:created)
          second_response = JSON.parse(response.body)
          
          expect(second_response).to eq(first_response)
        end
      end

      it "handles concurrent requests with same idempotency key safely" do
        login_as(user, scope: :user)
        
        travel_to Time.zone.parse("2025-01-15 10:00:00") do
          # First request
          post "/api/loans/#{approved_loan.id}/disburse",
               headers: { "Idempotency-Key" => "concurrent-key" }
          
          expect(response).to have_http_status(:created)
          
          # Second request with same key should return same result
          post "/api/loans/#{approved_loan.id}/disburse",
               headers: { "Idempotency-Key" => "concurrent-key" }
               
          expect(response).to have_http_status(:created)
          
          # Only one payment and two events should exist
          expect(Payment.count).to eq(1)
          expect(OutboxEvent.count).to eq(2)
        end
      end
    end

    context "authorization and validation" do
      it "allows loan owner to disburse their own loan" do
        login_as(user, scope: :user)
        
        post "/api/loans/#{approved_loan.id}/disburse",
             headers: { "Idempotency-Key" => "owner-key" }
        
        expect(response).to have_http_status(:created)
      end

      it "allows admin to disburse any loan" do
        login_as(admin_user, scope: :user)
        
        post "/api/loans/#{approved_loan.id}/disburse",
             headers: { "Idempotency-Key" => "admin-key" }
        
        expect(response).to have_http_status(:created)
      end

      it "forbids other users from disbursing loan" do
        login_as(other_user, scope: :user)
        
        post "/api/loans/#{approved_loan.id}/disburse",
             headers: { "Idempotency-Key" => "forbidden-key" }
        
        expect(response).to have_http_status(:forbidden)
      end

      it "requires Idempotency-Key header" do
        login_as(user, scope: :user)
        
        post "/api/loans/#{approved_loan.id}/disburse"
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to include("Idempotency-Key header is required")
      end

      it "rejects disbursement of non-approved loan" do
        pending_loan = create(:loan, user: user, state: "pending")
        login_as(user, scope: :user)
        
        post "/api/loans/#{pending_loan.id}/disburse",
             headers: { "Idempotency-Key" => "pending-key" }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to include("must be approved")
      end

      it "requires authentication" do
        post "/api/loans/#{approved_loan.id}/disburse",
             headers: { "Idempotency-Key" => "unauth-key" }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /admin/loans/:id/force_disburse" do
    context "admin override functionality" do
      it "allows admin to force disburse approved loan" do
        login_as(admin_user, scope: :user)
        
        expect {
          post "/admin/loans/#{approved_loan.id}/force_disburse"
        }.to change { approved_loan.reload.state }.from("approved").to("disbursed")
          .and change { Payment.count }.by(1)
          .and change { OutboxEvent.count }.by(2)

        expect(response).to redirect_to(admin_root_path)
        expect(flash[:notice]).to include("successfully disbursed")
      end

      it "handles already disbursed loan gracefully" do
        disbursed_loan = create(:loan, user: user, state: "disbursed")
        login_as(admin_user, scope: :user)
        
        expect {
          post "/admin/loans/#{disbursed_loan.id}/force_disburse"
        }.not_to change { Payment.count }

        expect(response).to redirect_to(admin_root_path)
        expect(flash[:notice]).to include("already disbursed")
      end

      it "rejects force disbursement by non-admin" do
        login_as(user, scope: :user)
        
        post "/admin/loans/#{approved_loan.id}/force_disburse"
        
        expect(response).to have_http_status(:found) # Redirect due to authorization failure
        expect(flash[:alert]).to include("not authorized")
      end

      it "logs audit entry for admin override" do
        login_as(admin_user, scope: :user)
        
        expect(AuditLogger).to receive(:log).with(
          "force_disburse_loan",
          admin_user,
          hash_including(
            loan_id: approved_loan.id,
            previous_state: "approved",
            new_state: "disbursed"
          )
        )
        
        post "/admin/loans/#{approved_loan.id}/force_disburse"
      end
    end
  end
end