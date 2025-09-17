require 'rails_helper'

RSpec.describe 'Core schema functionality', type: :model do
  describe 'User model with KYC and lending fields' do
    it 'creates a user with all lending fields' do
      user = create(:user,
                   full_name: "John Doe",
                   kyc_status: "approved",
                   credit_limit_cents: 50000_00,
                   current_score: 750)

      expect(user.full_name).to eq("John Doe")
      expect(user.kyc_status).to eq("approved")
      expect(user.credit_limit_cents).to eq(50000_00)
      expect(user.current_score).to eq(750)
      expect(user.referral_code).to be_present
    end

    it 'generates unique referral codes' do
      user1 = create(:user)
      user2 = create(:user)

      expect(user1.referral_code).not_to eq(user2.referral_code)
    end
  end

  describe 'Loan model with proper constraints' do
    it 'creates a micro loan correctly' do
      user = create(:user)
      loan = create(:loan, user: user, term_days: 30, amount_cents: 10000_00)

      expect(loan.product).to eq("micro")
      expect(loan.state).to eq("pending")
      expect(loan.amount_in_pesos).to eq(10000.0)
      expect(loan.principal_outstanding_cents).to eq(10000_00)
    end

    it 'auto-assigns product based on term_days' do
      user = create(:user)

      micro_loan = build(:loan, user: user, term_days: 30, product: nil)
      micro_loan.valid?
      expect(micro_loan.product).to eq("micro")

      extended_loan = build(:loan, user: user, term_days: 90, product: nil)
      extended_loan.valid?
      expect(extended_loan.product).to eq("extended")

      longterm_loan = build(:loan, user: user, term_days: 270, product: nil)
      longterm_loan.valid?
      expect(longterm_loan.product).to eq("longterm")
    end

    it 'validates longterm constraints' do
      user = create(:user)

      # Valid longterm terms - use valid amount for longterm loans (₱25,000-₱75,000)
      valid_loan = build(:loan, user: user, term_days: 270, amount_cents: 30_000_00, product: "longterm")
      expect(valid_loan).to be_valid

      valid_loan2 = build(:loan, user: user, term_days: 365, amount_cents: 30_000_00, product: "longterm")
      expect(valid_loan2).to be_valid

      # Invalid longterm terms
      invalid_loan = build(:loan, user: user, term_days: 300, amount_cents: 30_000_00, product: "longterm")
      expect(invalid_loan).not_to be_valid
      expect(invalid_loan.errors[:term_days]).to include('must be 270 or 365 days for longterm loans')
    end
  end

  describe 'Payment model with loan relationships' do
    it 'creates a payment for a loan' do
      loan = create(:loan, :disbursed)
      payment = create(:payment,
                      loan: loan,
                      amount_cents: 5000_00,
                      state: "cleared")

      expect(payment.loan).to eq(loan)
      expect(payment.amount_in_pesos).to eq(5000.0)
      expect(payment.state).to eq("cleared")
    end
  end

  describe 'Credit scoring functionality' do
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

      it 'updates user credit score when events are created' do
        user = create(:user, current_score: 600)

        expect {
          CreditScoreEvent.create!(
            user: user,
            reason: "on_time_payment",
            delta: 25,
            meta: { loan_id: "test" }
          )
          user.reload
        }.to change { user.current_score }.from(600).to(625)
      end

      it 'enforces credit score bounds' do
        # Test lower bound
        user = create(:user, current_score: 350)
        CreditScoreEvent.create!(user: user, reason: "default", delta: -100)
        user.reload
        expect(user.current_score).to eq(300)

        # Test upper bound
        user.update!(current_score: 850)
        CreditScoreEvent.create!(user: user, reason: "kyc_bonus", delta: 100)
        user.reload
        expect(user.current_score).to eq(950)
      end
    end

    context 'when legacy_delta_mode is disabled (default)' do
      it 'creates events without automatically updating scores' do
        user = create(:user, current_score: 600)

        expect {
          CreditScoreEvent.create!(
            user: user,
            reason: "on_time_payment",
            delta: 25,
            meta: { loan_id: "test" }
          )
          user.reload
        }.not_to change { user.current_score }
      end

      it 'score updates are handled by CreditScoringService' do
        user = create(:user, current_score: 600)
        service = Accounts::Services::CreditScoringService.new(user)

        expect {
          service.compute!(persist: true, emit_event: false)
          user.reload
        }.to change { user.current_score }
      end
    end
  end

  describe 'Referral system' do
    it 'creates referrals between users' do
      referrer = create(:user)
      referee = create(:user)
      promo_code = create(:promo_code, :referral)

      referral = create(:referral,
                       referrer: referrer,
                       referee: referee,
                       promo_code: promo_code)

      expect(referral.status).to eq("pending")
      expect(referral.referrer).to eq(referrer)
      expect(referral.referee).to eq(referee)
    end

    it 'prevents self-referrals' do
      user = create(:user)

      referral = build(:referral, referrer: user, referee: user)
      expect(referral).not_to be_valid
      expect(referral.errors[:referee]).to include("cannot refer yourself")
    end
  end

  describe 'Outbox event pattern' do
    it 'creates outbox events for domain events' do
      user = create(:user)
      loan = create(:loan, user: user)

      event = OutboxEvent.create!(
        name: "loan.created.v1",
        aggregate_id: loan.id,
        aggregate_type: "Loan",
        payload: { user_id: user.id, amount_cents: loan.amount_cents },
        headers: { correlation_id: SecureRandom.uuid }
      )

      expect(event.processed).to be false
      expect(event.attempts).to eq(0)
      expect(event.payload['user_id']).to eq(user.id)
    end
  end

  describe 'Idempotency keys' do
    it 'prevents duplicate operations' do
      user = create(:user)
      loan = create(:loan, user: user)

      key1 = IdempotencyKey.create!(
        key: "test-key-123",
        scope: "payments/webhook",
        resource: loan
      )

      # Should not allow duplicate key in same scope
      expect {
        IdempotencyKey.create!(
          key: "test-key-123",
          scope: "payments/webhook",
          resource: loan
        )
      }.to raise_error(ActiveRecord::RecordInvalid)

      # Should allow same key in different scope
      expect {
        IdempotencyKey.create!(
          key: "test-key-123",
          scope: "loans/disburse",
          resource: loan
        )
      }.not_to raise_error
    end
  end

  describe 'Audit logging' do
    it 'creates audit logs for user actions' do
      user = create(:user)
      loan = create(:loan, user: user)

      audit_log = AuditLog.create!(
        user: user,
        action: "loan.created",
        target: loan,
        changeset: { state: [ nil, "pending" ] },
        ip: "127.0.0.1",
        user_agent: "Test/1.0"
      )

      expect(audit_log.user).to eq(user)
      expect(audit_log.target).to eq(loan)
      expect(audit_log.action).to eq("loan.created")
    end
  end
end
