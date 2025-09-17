# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Loans::Services::LoanState, type: :service do
  let(:service) { described_class.new }
  let(:user) { create(:user, :kyc_approved) }
  let(:loan) { create(:loan, :pending, user: user) }
  let(:correlation_id) { SecureRandom.uuid }

  describe '#reject!' do
    let(:actor) { create(:user) }
    let(:reason) { 'Insufficient credit score' }

    context 'when loan is in pending state' do
      it 'transitions loan to rejected state' do
        service.reject!(loan, actor: actor, reason: reason, correlation_id: correlation_id)
        
        expect(loan.reload.state).to eq('rejected')
      end

      it 'emits loan.rejected.v1 event' do
        service.reject!(loan, actor: actor, reason: reason, correlation_id: correlation_id)
        
        event = OutboxEvent.last
        expect(event.name).to eq('loan.rejected.v1')
        expect(event.aggregate_id).to eq(loan.id)
        expect(event.payload).to include(
          'loan_id' => loan.id,
          'user_id' => loan.user_id,
          'reason' => reason
        )
        expect(event.headers['correlation_id']).to eq(correlation_id)
        expect(event.headers['actor_id']).to eq(actor.id)
      end
    end

    context 'when loan is not in pending state' do
      it 'raises InvalidStateTransitionError' do
        loan.update!(state: 'approved')
        
        expect {
          service.reject!(loan, actor: actor, reason: reason, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::InvalidStateTransitionError,
          'Cannot reject loan in state: approved'
        )
      end
    end
  end

  describe '#mark_as_defaulted!' do
    let(:overdue_loan) do
      create(:loan, user: user, state: 'disbursed', principal_outstanding_cents: 50000_00).tap do |loan|
        # Manually update due_on to past date without validations to make it overdue
        loan.update_column(:due_on, 35.days.ago.to_date)
        # Then transition to overdue state
        loan.update_column(:state, 'overdue')
      end
    end

    context 'when loan is overdue beyond threshold' do
      it 'transitions loan to defaulted state' do
        service.mark_as_defaulted!(overdue_loan, correlation_id: correlation_id)
        
        expect(overdue_loan.reload.state).to eq('defaulted')
      end

      it 'emits loan.defaulted.v1 event' do
        service.mark_as_defaulted!(overdue_loan, correlation_id: correlation_id)
        
        event = OutboxEvent.last
        expect(event.name).to eq('loan.defaulted.v1')
        expect(event.aggregate_id).to eq(overdue_loan.id)
        expect(event.payload).to include(
          'loan_id' => overdue_loan.id,
          'user_id' => overdue_loan.user_id,
          'outstanding_balance_cents' => overdue_loan.outstanding_balance_cents,
          'days_overdue' => overdue_loan.days_overdue
        )
        expect(event.headers['correlation_id']).to eq(correlation_id)
      end
    end

    context 'when loan has not reached defaulted threshold' do
      let(:recent_overdue_loan) do
        create(:loan, user: user, state: 'disbursed', principal_outstanding_cents: 50000_00).tap do |loan|
          loan.update_column(:due_on, 15.days.ago.to_date) # Less than 30 days
          loan.update_column(:state, 'overdue')
        end
      end

      it 'raises GuardFailedError' do
        expect {
          service.mark_as_defaulted!(recent_overdue_loan, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::GuardFailedError,
          /Loan has not reached defaulted threshold/
        )
      end
    end

    context 'when loan is not in overdue or disbursed state' do
      let(:pending_loan) { create(:loan, user: user, state: 'pending') }

      it 'raises InvalidStateTransitionError' do
        expect {
          service.mark_as_defaulted!(pending_loan, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::InvalidStateTransitionError,
          'Cannot mark as defaulted from state: pending'
        )
      end
    end
  end

  describe '#approve!' do
    context 'when all guards pass' do
      it 'transitions loan to approved state' do
        service.approve!(loan, correlation_id: correlation_id)
        
        expect(loan.reload.state).to eq('approved')
      end

      it 'emits loan.approved.v1 event' do
        service.approve!(loan, correlation_id: correlation_id)
        
        event = OutboxEvent.last
        expect(event.name).to eq('loan.approved.v1')
        expect(event.aggregate_id).to eq(loan.id)
        expect(event.aggregate_type).to eq('Loan')
        expect(event.payload).to include(
          'loan_id' => loan.id,
          'user_id' => loan.user_id,
          'amount_cents' => loan.amount_cents,
          'term_days' => loan.term_days,
          'product' => loan.product
        )
        expect(event.headers['correlation_id']).to eq(correlation_id)
      end

      it 'includes actor in event headers when provided' do
        actor = create(:user)
        service.approve!(loan, actor: actor, correlation_id: correlation_id)
        
        event = OutboxEvent.last
        expect(event.headers['actor_id']).to eq(actor.id)
      end
    end

    context 'when loan is not in pending state' do
      it 'raises InvalidStateTransitionError' do
        loan.update!(state: 'approved')
        
        expect {
          service.approve!(loan, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::InvalidStateTransitionError,
          'Cannot approve loan in state: approved'
        )
      end
    end

    context 'when user KYC is not approved' do
      before { user.update!(kyc_status: 'pending') }

      it 'raises GuardFailedError' do
        expect {
          service.approve!(loan, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::GuardFailedError,
          'User KYC must be approved to approve loan'
        )
      end
    end

    context 'when user has overdue loans' do
      before { create(:loan, :overdue, user: user) }

      it 'raises GuardFailedError' do
        expect {
          service.approve!(loan, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::GuardFailedError,
          'User has overdue loans, cannot approve new loan'
        )
      end
    end
  end

  describe '#disburse!' do
    let(:gateway) { double('PaymentGateway') }
    let(:idem_key) { 'disbursement-12345' }
    let(:gateway_ref) { 'txn-abcd1234' }

    before do
      loan.update!(state: 'approved')
      allow(gateway).to receive(:disburse).and_return(gateway_ref)
    end

    context 'when all guards pass' do
      it 'transitions loan to disbursed state' do
        service.disburse!(loan, gateway: gateway, idem_key: idem_key, correlation_id: correlation_id)
        
        expect(loan.reload.state).to eq('disbursed')
      end

      it 'calls gateway to disburse funds' do
        expect(gateway).to receive(:disburse).with(
          amount_cents: loan.amount_cents,
          recipient: loan.user
        ).and_return(gateway_ref)
        
        service.disburse!(loan, gateway: gateway, idem_key: idem_key, correlation_id: correlation_id)
      end

      it 'creates pending payment record with gateway reference' do
        service.disburse!(loan, gateway: gateway, idem_key: idem_key, correlation_id: correlation_id)
        
        payment = loan.payments.last
        expect(payment.amount_cents).to eq(loan.amount_cents)
        expect(payment.state).to eq('pending')
        expect(payment.gateway_ref).to eq(gateway_ref)
        expect(payment.posted_at).to be_present
      end

      it 'emits loan.disbursed.v1 event' do
        service.disburse!(loan, gateway: gateway, idem_key: idem_key, correlation_id: correlation_id)
        
        event = OutboxEvent.last
        expect(event.name).to eq('loan.disbursed.v1')
        expect(event.aggregate_id).to eq(loan.id)
        expect(event.payload).to include(
          'loan_id' => loan.id,
          'user_id' => loan.user_id,
          'amount_cents' => loan.amount_cents,
          'gateway_ref' => gateway_ref
        )
        expect(event.headers['correlation_id']).to eq(correlation_id)
        expect(event.headers['gateway_ref']).to eq(gateway_ref)
      end

      it 'creates idempotency key record' do
        service.disburse!(loan, gateway: gateway, idem_key: idem_key, correlation_id: correlation_id)
        
        idem_record = IdempotencyKey.find_by(key: idem_key, scope: 'loans/disburse')
        expect(idem_record).to be_present
        expect(idem_record.resource).to eq(loan)
      end
    end

    context 'when idempotency key already exists for same resource' do
      before do
        IdempotencyKey.create!(
          key: idem_key,
          scope: 'loans/disburse',
          resource: loan
        )
      end

      it 'does not raise error and allows operation to proceed' do
        expect {
          service.disburse!(loan, gateway: gateway, idem_key: idem_key, correlation_id: correlation_id)
        }.not_to raise_error
      end
    end

    context 'when idempotency key already exists for different resource' do
      let(:other_loan) { create(:loan, :approved, user: user) }

      before do
        IdempotencyKey.create!(
          key: idem_key,
          scope: 'loans/disburse',
          resource: other_loan
        )
      end

      it 'raises error' do
        expect {
          service.disburse!(loan, gateway: gateway, idem_key: idem_key, correlation_id: correlation_id)
        }.to raise_error(StandardError, "Idempotency key '#{idem_key}' already used for different resource")
      end
    end

    context 'when loan is not in approved state' do
      before { loan.update!(state: 'pending') }

      it 'raises InvalidStateTransitionError' do
        expect {
          service.disburse!(loan, gateway: gateway, idem_key: idem_key, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::InvalidStateTransitionError,
          'Cannot disburse loan in state: pending'
        )
      end
    end

    context 'when concurrent calls are made' do
      it 'ensures thread safety with locks' do
        # This tests that with_lock prevents race conditions
        threads = []
        results = []
        
        2.times do
          threads << Thread.new do
            begin
              service.disburse!(loan, gateway: gateway, idem_key: idem_key, correlation_id: correlation_id)
              results << :success
            rescue => e
              results << e.class
            end
          end
        end
        
        threads.each(&:join)
        
        # One should succeed, the other might fail due to idempotency or state
        expect(results).to include(:success)
        expect(loan.reload.state).to eq('disbursed')
      end
    end
  end

  describe '#mark_as_paid!' do
    before do
      loan.update!(
        state: 'disbursed',
        principal_outstanding_cents: 0,
        interest_accrued_cents: 0,
        penalty_accrued_cents: 0
      )
    end

    context 'when outstanding balance is zero' do
      it 'transitions loan to paid state' do
        service.mark_as_paid!(loan, correlation_id: correlation_id)
        
        expect(loan.reload.state).to eq('paid')
      end

      it 'emits loan.paid.v1 event' do
        service.mark_as_paid!(loan, correlation_id: correlation_id)
        
        event = OutboxEvent.last
        expect(event.name).to eq('loan.paid.v1')
        expect(event.aggregate_id).to eq(loan.id)
        expect(event.payload).to include(
          'loan_id' => loan.id,
          'user_id' => loan.user_id,
          'principal_cents' => loan.amount_cents,
          'total_paid_cents' => loan.amount_cents
        )
        expect(event.headers['correlation_id']).to eq(correlation_id)
      end
    end

    context 'when outstanding balance is not zero' do
      before do
        loan.update!(principal_outstanding_cents: 1000_00)
      end

      it 'raises GuardFailedError' do
        expect {
          service.mark_as_paid!(loan, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::GuardFailedError,
          'Cannot mark as paid: outstanding balance is 100000 cents'
        )
      end
    end
  end

  describe '#mark_as_overdue!' do
    let(:loan) do
      create(:loan, :disbursed, user: user, principal_outstanding_cents: 50000).tap do |l|
        l.update_columns(due_on: Date.current - 2.days)
      end
    end

    context 'when loan is overdue by business logic' do
      it 'transitions loan to overdue state' do
        service.mark_as_overdue!(loan, correlation_id: correlation_id)
        
        expect(loan.reload.state).to eq('overdue')
      end

      it 'emits loan.overdue.v1 event' do
        service.mark_as_overdue!(loan, correlation_id: correlation_id)
        
        event = OutboxEvent.last
        expect(event.name).to eq('loan.overdue.v1')
        expect(event.aggregate_id).to eq(loan.id)
        expect(event.payload).to include(
          'loan_id' => loan.id,
          'user_id' => loan.user_id,
          'principal_cents' => loan.amount_cents,
          'outstanding_balance_cents' => loan.outstanding_balance_cents
        )
        expect(event.payload['days_overdue']).to be > 0
        expect(event.headers['correlation_id']).to eq(correlation_id)
      end
    end

    context 'when loan is not in disbursed state' do
      let(:loan) { create(:loan, :pending, user: user) }

      it 'raises InvalidStateTransitionError' do
        expect {
          service.mark_as_overdue!(loan, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::InvalidStateTransitionError,
          'Cannot mark as overdue from state: pending'
        )
      end
    end

    context 'when loan is not actually overdue' do
      let(:loan) do
        create(:loan, :disbursed, user: user, principal_outstanding_cents: 50000).tap do |l|
          l.update_columns(due_on: Date.current + 2.days)
        end
      end

      it 'raises GuardFailedError' do
        expect {
          service.mark_as_overdue!(loan, correlation_id: correlation_id)
        }.to raise_error(
          Loans::Services::LoanState::GuardFailedError,
          'Loan is not past due date or has zero balance'
        )
      end
    end
  end

  describe 'thread safety' do
    it 'ensures atomic operations with database locks' do
      # Test that state transitions are atomic and thread-safe
      threads = []
      errors = []
      
      5.times do |i|
        threads << Thread.new do
          begin
            local_service = described_class.new
            local_service.approve!(loan, correlation_id: "test-#{i}")
          rescue => e
            errors << e
          end
        end
      end
      
      threads.each(&:join)
      
      # Only one should succeed
      expect(loan.reload.state).to eq('approved')
      expect(errors.length).to eq(4) # 4 should fail due to state check
    end
  end
end