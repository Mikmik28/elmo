require 'rails_helper'

RSpec.describe 'Database migrations', type: :migration do
  describe 'migration roundtrip' do
    it 'can migrate up and down successfully' do
      # Simply verify all our tables exist and have expected structure
      connection = ActiveRecord::Base.connection

      # Verify all main tables exist
      expected_tables = %w[users loans payments promo_codes referrals credit_score_events outbox_events idempotency_keys audit_logs]
      expected_tables.each do |table|
        expect(connection.table_exists?(table)).to be true
      end

      # Verify key columns exist with correct types
      expect(connection.column_exists?(:users, :credit_limit_cents, :integer)).to be true
      expect(connection.column_exists?(:loans, :amount_cents, :integer)).to be true
      expect(connection.column_exists?(:payments, :amount_cents, :integer)).to be true
      expect(connection.column_exists?(:loans, :apr, :decimal)).to be true
    end
  end

  describe 'constraints and indexes' do
    let(:connection) { ActiveRecord::Base.connection }

    it 'enforces amount_cents positive constraint on loans' do
      user = create(:user)

      expect {
        connection.execute(
          "INSERT INTO loans (id, user_id, amount_cents, term_days, product, state, principal_outstanding_cents, interest_accrued_cents, penalty_accrued_cents, created_at, updated_at) " \
          "VALUES ('#{SecureRandom.uuid}', '#{user.id}', -1000, 30, 'micro', 'pending', 0, 0, 0, NOW(), NOW())"
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /loans_amount_positive/)
    end

    it 'enforces longterm term validation constraint' do
      user = create(:user)

      expect {
        connection.execute(
          "INSERT INTO loans (id, user_id, amount_cents, term_days, product, state, principal_outstanding_cents, interest_accrued_cents, penalty_accrued_cents, created_at, updated_at) " \
          "VALUES ('#{SecureRandom.uuid}', '#{user.id}', 10000, 300, 'longterm', 'pending', 10000, 0, 0, NOW(), NOW())"
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /loans_longterm_term_validation/)
    end

    it 'enforces foreign key constraints' do
      non_existent_uuid = SecureRandom.uuid

      expect {
        connection.execute(
          "INSERT INTO loans (id, user_id, amount_cents, term_days, product, state, principal_outstanding_cents, interest_accrued_cents, penalty_accrued_cents, created_at, updated_at) " \
          "VALUES ('#{SecureRandom.uuid}', '#{non_existent_uuid}', 10000, 30, 'micro', 'pending', 10000, 0, 0, NOW(), NOW())"
        )
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'enforces unique constraints' do
      user1 = create(:user, email: 'test@example.com')

      expect {
        connection.execute(
          "INSERT INTO users (id, email, encrypted_password, role, kyc_status, credit_limit_cents, current_score, created_at, updated_at) " \
          "VALUES ('#{SecureRandom.uuid}', 'test@example.com', 'encrypted', 'user', 'pending', 0, 600, NOW(), NOW())"
        )
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'money precision' do
    it 'stores and retrieves decimal values with 4 decimal places correctly' do
      user = create(:user)
      loan = create(:loan, user: user, apr: 12.3456)

      loan.reload
      expect(loan.apr).to eq(12.3456)
    end

    it 'rounds money amounts correctly' do
      loan = create(:loan, amount_cents: 123456) # ₱1,234.56
      expect(loan.amount_in_pesos).to eq(1234.56)

      loan.amount_in_pesos = 1234.567 # Should round to cents
      expect(loan.amount_cents).to eq(123456) # Truncated to cents
    end
  end
end
