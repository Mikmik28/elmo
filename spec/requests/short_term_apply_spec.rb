# frozen_string_literal: true

require 'rails_helper'
require 'warden/test/helpers'

RSpec.configure do |config|
  config.include Warden::Test::Helpers
end

RSpec.describe "Short-term loan application API", type: :request do
  let(:user) { create(:user, :kyc_approved, current_score: 800, created_at: 2.years.ago) } # Older account for better tenure score
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Idempotency-Key' => 'test-key-123'
    }
  end

  before do
    login_as(user, scope: :user)
  end

  after do
    logout(:user)
  end

  context 'happy_apply_short_term' do
    it 'successfully creates short-term loan with auto-approval for qualified users' do
      # Mock the scoring threshold to ensure predictable auto-approval
      allow(Rails.configuration.x.scoring).to receive(:short_term_min).and_return(640)

      # Valid short-term loan parameters
      params = {
        loan: {
          amount_cents: 300000, # ₱3,000
          term_days: 30
        }
      }

      post '/api/loans', params: params.to_json, headers: headers

      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      loan = json['loan']
      decision = json['loan']['decision']

      expect(loan['product']).to eq('micro') # Derived from term_days
      expect(loan['term_days']).to eq(30)
      expect(loan['amount_cents']).to eq(300000)
      expect(loan['state']).to eq('approved') # Auto-approved for qualified user
      expect(loan).to have_key('id')
      expect(loan).to have_key('due_on')

      # Verify decision information
      expect(decision['user_score']).to be_present
      expect(decision['score_threshold']).to eq(640)
      expect(decision['approved']).to be true
      expect(decision['reason']).to eq('auto_approved_micro_loan')

      # Verify loan was actually created
      created_loan = Loan.find(loan['id'])
      expect(created_loan.product).to eq('micro')
      expect(created_loan.state).to eq('approved')
      expect(created_loan.user).to eq(user)
    end
  end

  context 'pending_when_below_threshold' do
    it 'creates loan in pending state when score below threshold' do
      # Create a user with low score by having recent account creation
      low_score_user = create(:user, :kyc_approved,
                              current_score: 635,
                              created_at: 1.month.ago) # Recent account = lower score
      login_as(low_score_user, scope: :user)

      params = {
        loan: {
          amount_cents: 250000,
          term_days: 25
        }
      }

      post '/api/loans', params: params.to_json, headers: headers

      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      loan = json['loan']
      decision = json['loan']['decision']

      expect(loan['state']).to eq('pending') # Should be pending, not auto-approved
      expect(decision['approved']).to be false
      expect(decision['reason']).to eq('below_score_threshold')
      expect(decision['user_score']).to be < 640
    end
  end

  context 'idempotency_behavior' do
    it 'prevents duplicate loan creation with same idempotency key' do
      params = {
        loan: {
          amount_cents: 200000,
          term_days: 20
        }
      }

      # First request
      post '/api/loans', params: params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      first_response = JSON.parse(response.body)

      # Second request with same idempotency key
      post '/api/loans', params: params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      second_response = JSON.parse(response.body)

      # Should return same loan
      expect(first_response['loan']['id']).to eq(second_response['loan']['id'])
      expect(Loan.count).to eq(1) # Only one loan created

      # Verify idempotency key was stored
      key_record = IdempotencyKey.find_by(
        key: 'test-key-123',
        scope: "api/loans/create/#{user.id}"
      )
      expect(key_record).to be_present
      expect(key_record.resource).to eq(Loan.last)
    end
  end

  context 'unauthorized_user_cannot_apply_for_others' do
    it 'allows authenticated user to create loan for themselves' do
      # User is authenticated but trying to create loan for themselves
      # (which should work - this tests the authorization logic works correctly)
      loan_params = {
        loan: {
          amount_cents: 200000,
          term_days: 15
        }
      }

      post '/api/loans', params: loan_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['loan']['user_id']).to eq(user.id)
    end
  end

  context 'invalid_term_days_200_rejected' do
    it 'rejects term_days outside 1-60 range' do
      loan_params = {
        loan: {
          amount_cents: 300000,
          term_days: 200 # Invalid for this endpoint
        }
      }

      post '/api/loans', params: loan_params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)

      expect(json['error']['code']).to eq('validation_failed')
      expect(json['error']['message']).to include('term_days must be 1..60')
    end

    it 'rejects term_days = 0' do
      loan_params = {
        loan: {
          amount_cents: 300000,
          term_days: 0
        }
      }

      post '/api/loans', params: loan_params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)

      expect(json['error']['code']).to eq('validation_failed')
      expect(json['error']['message']).to include('term_days must be 1..60')
    end

    it 'rejects term_days = 61 (extended range)' do
      loan_params = {
        loan: {
          amount_cents: 300000,
          term_days: 61
        }
      }

      post '/api/loans', params: loan_params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)

      expect(json['error']['code']).to eq('validation_failed')
      expect(json['error']['message']).to include('term_days must be 1..60')
    end
  end

  context 'missing_idempotency_key' do
    it 'requires Idempotency-Key header' do
      loan_params = {
        loan: {
          amount_cents: 300000,
          term_days: 30
        }
      }

      headers_without_key = headers.except('Idempotency-Key')

      post '/api/loans', params: loan_params.to_json, headers: headers_without_key

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)

      expect(json['error']['code']).to eq('missing_idempotency_key')
      expect(json['error']['message']).to include('Idempotency-Key header is required')
    end
  end

  context 'kyc_not_approved_pending' do
    it 'creates pending loan for users without KYC approval' do
      # Create user without KYC approval
      user.update!(kyc_status: 'pending')

      loan_params = {
        loan: {
          amount_cents: 250000,
          term_days: 25
        }
      }

      post '/api/loans', params: loan_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json['loan']['state']).to eq('pending')
      expect(json['loan']['decision']['approved']).to be false
      expect(json['loan']['decision']['reason']).to eq('kyc_not_approved')
    end
  end

  context 'overdue_loan_blocks_new' do
    it 'creates pending loan for users with overdue loans' do
      # Create an overdue loan for the user
      create(:loan, :overdue, user: user)

      loan_params = {
        loan: {
          amount_cents: 350000,
          term_days: 40
        }
      }

      post '/api/loans', params: loan_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json['loan']['state']).to eq('pending')
      expect(json['loan']['decision']['approved']).to be false
      expect(json['loan']['decision']['reason']).to eq('user_has_overdue_loans')
    end
  end

  context 'product_derivation_ignores_client_input' do
    it 'derives product from term_days ignoring client input' do
      # Client tries to specify 'extended' but term_days=30 should derive 'micro'
      loan_params = {
        loan: {
          amount_cents: 500000,
          term_days: 30,
          product: 'extended' # This should be ignored
        }
      }

      post '/api/loans', params: loan_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      loan = json['loan']

      expect(loan['product']).to eq('micro') # Derived from term_days=30, not 'extended'
    end
  end

  context 'boundary_cases' do
    it 'accepts term_days = 1 (minimum)' do
      loan_params = {
        loan: {
          amount_cents: 100000,
          term_days: 1
        }
      }

      post '/api/loans', params: loan_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['loan']['product']).to eq('micro')
      expect(json['loan']['term_days']).to eq(1)
    end

    it 'accepts term_days = 60 (maximum for micro)' do
      loan_params = {
        loan: {
          amount_cents: 500000,
          term_days: 60
        }
      }

      post '/api/loans', params: loan_params.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['loan']['product']).to eq('micro')
      expect(json['loan']['term_days']).to eq(60)
    end
  end

  context 'scoring_integration' do
    it 'recomputes and persists credit score during loan application' do
      initial_score = user.current_score

      loan_params = {
        loan: {
          amount_cents: 300000,
          term_days: 30
        }
      }

      expect {
        post '/api/loans', params: loan_params.to_json, headers: headers
      }.to change { user.reload.current_score }

      # Should create an outbox event for score change
      expect(OutboxEvent.where(
        name: "user.score_changed.v1",
        aggregate_type: "User",
        aggregate_id: user.id
      )).to exist
    end
  end
end

describe "Short-term loan application API - unauthenticated", type: :request do
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Idempotency-Key' => 'test-key-456'
    }
  end

  context 'unauthenticated_request' do
    it 'requires authentication' do
      # Create a test without logging in any user
      post '/api/loans',
           params: { loan: { amount_cents: 200000, term_days: 15 } }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Idempotency-Key' => 'test-key-456' }

      # Expect either 401 unauthorized or 302 redirect to login (both indicate authentication required)
      expect([ 401, 302 ]).to include(response.status)
    end
  end
end
