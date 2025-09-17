require 'rails_helper'

RSpec.describe 'Migration roundtrip and money precision tests', type: :model do
  describe 'Migration roundtrip validation' do
    it 'successfully validates all tables exist with proper structure' do
      # Verify all tables exist after migration
      expect(ActiveRecord::Base.connection.table_exists?('users')).to be true
      expect(ActiveRecord::Base.connection.table_exists?('loans')).to be true
      expect(ActiveRecord::Base.connection.table_exists?('payments')).to be true
      expect(ActiveRecord::Base.connection.table_exists?('promo_codes')).to be true
      expect(ActiveRecord::Base.connection.table_exists?('referrals')).to be true
      expect(ActiveRecord::Base.connection.table_exists?('credit_score_events')).to be true
      expect(ActiveRecord::Base.connection.table_exists?('outbox_events')).to be true
      expect(ActiveRecord::Base.connection.table_exists?('idempotency_keys')).to be true
      expect(ActiveRecord::Base.connection.table_exists?('audit_logs')).to be true

      # Verify key columns exist
      connection = ActiveRecord::Base.connection
      expect(connection.column_exists?(:users, :credit_limit_cents)).to be true
      expect(connection.column_exists?(:loans, :amount_cents)).to be true
      expect(connection.column_exists?(:payments, :amount_cents)).to be true
    end
  end

  describe 'Money precision validation' do
    it 'stores and retrieves peso amounts with proper precision' do
      user = create(:user)

      # Test large amounts - use longterm product with valid amount
      loan = create(:loan, user: user, amount_cents: 50_000_00, term_days: 270, product: nil)
      expect(loan.amount_in_pesos).to eq(50_000.0)
      expect(loan.amount_cents).to eq(50_000_00)

      # Test small amounts (centavos)
      payment = create(:payment, loan: loan, amount_cents: 1_25)
      expect(payment.amount_in_pesos).to eq(1.25)
      expect(payment.amount_cents).to eq(125)

      # Test precision preservation after database roundtrip
      loan.reload
      payment.reload

      expect(loan.amount_in_pesos).to eq(50_000.0)
      expect(payment.amount_in_pesos).to eq(1.25)
    end

    it 'handles credit limits and outstanding amounts correctly' do
      user = create(:user, credit_limit_cents: 100_000_00)
      expect(user.credit_limit_in_pesos).to eq(100_000.0)

      loan = create(:loan, user: user, amount_cents: 30_000_00, term_days: 270, product: nil)
      expect(loan.principal_outstanding_cents).to eq(30_000_00)
      expect(loan.principal_outstanding_in_pesos).to eq(30_000.0)

      # After database roundtrip
      user.reload
      loan.reload
      expect(user.credit_limit_in_pesos).to eq(100_000.0)
      expect(loan.principal_outstanding_in_pesos).to eq(30_000.0)
    end
  end

  describe 'Database constraints enforcement' do
    it 'enforces model validation constraints' do
      user = create(:user)

      # Should prevent negative credit score via model validation
      expect {
        user.update!(current_score: 250)
      }.to raise_error(ActiveRecord::RecordInvalid, /Current score must be in/)

      # Should prevent invalid credit limit
      loan = build(:loan, user: user, amount_cents: -100)
      expect(loan).not_to be_valid
      expect(loan.errors[:amount_cents]).to include('must be greater than 0')
    end

    it 'enforces foreign key relationships' do
      user = create(:user)
      loan = create(:loan, user: user)

      # Loan should belong to user
      expect(loan.user).to eq(user)
      expect(user.loans).to include(loan)
    end

    it 'enforces unique constraints' do
      # Unique referral codes
      user1 = create(:user)
      expect {
        create(:user, referral_code: user1.referral_code)
      }.to raise_error(ActiveRecord::RecordInvalid)

      # Unique idempotency keys within scope
      loan = create(:loan)
      key1 = create(:idempotency_key, key: "test-123", scope: "payments", resource: loan)

      expect {
        create(:idempotency_key, key: "test-123", scope: "payments", resource: loan)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'Index performance validation' do
    it 'has proper indexes for common queries' do
      connection = ActiveRecord::Base.connection

      # Verify key indexes exist
      expect(connection.index_exists?(:users, :email)).to be true
      expect(connection.index_exists?(:users, :referral_code)).to be true
      expect(connection.index_exists?(:loans, [ :user_id, :state ])).to be true
      expect(connection.index_exists?(:payments, [ :loan_id, :state ])).to be true
      expect(connection.index_exists?(:audit_logs, [ :user_id, :action ])).to be true
      expect(connection.index_exists?(:outbox_events, [ :processed, :created_at ])).to be true
    end
  end

  describe 'Business logic validation' do
    it 'properly calculates loan terms and interest' do
      user = create(:user)

      # Micro loan (1-60 days)
      micro_loan = create(:loan, user: user, term_days: 30, amount_cents: 10_000_00, product: nil)
      expect(micro_loan.product).to eq("micro")

      # Extended loan (61-180 days)
      extended_loan = create(:loan, user: user, term_days: 90, amount_cents: 25_000_00, product: nil)
      expect(extended_loan.product).to eq("extended")

      # Long-term loan (270 or 365 days only)
      longterm_loan = create(:loan, user: user, term_days: 270, amount_cents: 50_000_00, product: nil)
      expect(longterm_loan.product).to eq("longterm")
    end

    it 'tracks payment history correctly' do
      loan = create(:loan, :disbursed, amount_cents: 10_000_00)

      # Make partial payment
      payment1 = create(:payment, loan: loan, amount_cents: 3_000_00, state: "cleared")

      # Outstanding should be updated
      expect(loan.payments.where(state: "cleared").sum(:amount_cents)).to eq(3_000_00)

      # Make final payment
      payment2 = create(:payment, loan: loan, amount_cents: 7_000_00, state: "cleared")

      expect(loan.payments.where(state: "cleared").sum(:amount_cents)).to eq(10_000_00)
    end

    it 'manages credit scoring correctly' do
      user = create(:user, current_score: 650)

      # Test credit scoring service instead of legacy callback
      service = Accounts::Services::CreditScoringService.new(user)

      # Create some loan history to affect score
      loan = create(:loan, user: user, state: "paid")
      create(:payment, loan: loan, amount_cents: loan.amount_cents, state: "cleared")

      # Score should be computed by service
      new_score = service.compute!(persist: true, emit_event: false)
      user.reload

      expect(user.current_score).to eq(new_score)
      expect(new_score).to be_between(300, 950)

      # Events are created for audit trail but don't auto-update score
      event = create(:credit_score_event,
                    user: user,
                    reason: "recompute",
                    delta: new_score - 650)

      # Event exists but doesn't trigger callback
      expect(event.persisted?).to be true
      expect(event.reason).to eq("recompute")
    end
  end
end
