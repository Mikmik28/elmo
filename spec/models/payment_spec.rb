# == Schema Information
#
# Table name: payments
#
#  id              :uuid             not null, primary key
#  amount_cents    :integer          not null
#  gateway_payload :jsonb
#  gateway_ref     :string
#  posted_at       :datetime
#  state           :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  loan_id         :uuid             not null
#
# Indexes
#
#  index_payments_on_gateway_ref        (gateway_ref) UNIQUE
#  index_payments_on_loan_id            (loan_id)
#  index_payments_on_loan_id_and_state  (loan_id,state)
#  index_payments_on_posted_at          (posted_at)
#  index_payments_on_state              (state)
#
# Foreign Keys
#
#  fk_rails_...  (loan_id => loans.id)
#
require 'rails_helper'

RSpec.describe Payment, type: :model do
  describe 'associations' do
    it { should belong_to(:loan) }
  end

  describe 'validations' do
    subject { build(:payment) }

    it { should validate_presence_of(:amount_cents) }
    it { should validate_numericality_of(:amount_cents).is_greater_than(0) }
    it { should validate_uniqueness_of(:gateway_ref).allow_blank }
  end

  describe 'enums' do
    it { should define_enum_for(:state).with_values(pending: 'pending', cleared: 'cleared', failed: 'failed').backed_by_column_of_type(:string).with_prefix(:state) }
  end

  describe 'enum predicates' do
    let(:payment) { build(:payment, state: 'pending') }

    it 'responds to prefixed state predicates' do
      expect(payment).to respond_to(:state_pending?)
      expect(payment).to respond_to(:state_cleared?)
      expect(payment).to respond_to(:state_failed?)
    end

    it 'responds to unprefixed state predicates (aliases)' do
      expect(payment).to respond_to(:pending?)
      expect(payment).to respond_to(:cleared?)
      expect(payment).to respond_to(:failed?)
    end

    it 'returns correct values for state predicates' do
      expect(payment.state_pending?).to be true
      expect(payment.pending?).to be true
      expect(payment.state_cleared?).to be false
      expect(payment.cleared?).to be false
    end
  end

  describe 'money methods' do
    let(:payment) { create(:payment, amount_cents: 5000_00) }

    it 'converts amount_cents to pesos' do
      expect(payment.amount_in_pesos).to eq(5000.0)
    end

    it 'sets amount from pesos' do
      payment.amount_in_pesos = 7500.0
      expect(payment.amount_cents).to eq(7500_00)
    end
  end

  describe 'state predicates' do
    it 'successful? returns true for cleared payments' do
      payment = create(:payment, :cleared)
      expect(payment.successful?).to be true
    end

    it 'failed_or_pending? returns true for failed or pending payments' do
      failed_payment = create(:payment, :failed)
      pending_payment = create(:payment, state: 'pending')

      expect(failed_payment.failed_or_pending?).to be true
      expect(pending_payment.failed_or_pending?).to be true
    end
  end

  describe 'scopes' do
    let!(:cleared_payment) { create(:payment, :cleared) }
    let!(:failed_payment) { create(:payment, :failed) }
    let!(:pending_payment) { create(:payment, state: 'pending') }

    it 'successful scope returns cleared payments' do
      expect(Payment.successful).to contain_exactly(cleared_payment)
    end

    it 'recent scope orders by created_at desc' do
      expect(Payment.recent.first).to eq(pending_payment)
    end
  end

  describe 'callbacks' do
    let(:loan) { create(:loan, :disbursed, principal_outstanding_cents: 10000_00) }
    let(:payment) { create(:payment, loan: loan, amount_cents: 5000_00, state: 'pending') }

    it 'updates loan balance when payment is cleared' do
      expect {
        payment.update!(state: 'cleared')
        loan.reload
      }.to change { loan.principal_outstanding_cents }.from(10000_00).to(5000_00)
    end

    it 'marks loan as paid when full payment clears the balance' do
      payment.update!(amount_cents: 10000_00)
      expect {
        payment.update!(state: 'cleared')
        loan.reload
      }.to change { loan.state }.from('disbursed').to('paid')
        .and change { loan.principal_outstanding_cents }.to(0)
    end
  end
end
