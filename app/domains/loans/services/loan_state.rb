# frozen_string_literal: true

module Loans
  module Services
    class LoanState
      class InvalidStateTransitionError < StandardError; end
      class GuardFailedError < StandardError; end

      def approve!(loan, actor: nil, correlation_id: SecureRandom.uuid)
        with_transaction_and_lock(loan) do
          guard_can_approve!(loan)
          
          loan.update!(state: "approved")
          
          OutboxEvent.publish!(
            name: "loan.approved.v1",
            aggregate: loan,
            payload: {
              loan_id: loan.id,
              user_id: loan.user_id,
              amount_cents: loan.amount_cents,
              term_days: loan.term_days,
              product: loan.product,
              approved_at: Time.current.iso8601
            },
            headers: {
              correlation_id: correlation_id,
              actor_id: actor&.id
            }
          )
        end
      end

      def disburse!(loan, gateway:, idem_key:, correlation_id: SecureRandom.uuid)
        IdempotencyKey.lock_or_raise!(
          key: idem_key,
          scope: "loans/disburse",
          resource: loan
        )

        with_transaction_and_lock(loan) do
          guard_can_disburse!(loan)
          
          # Gateway call to actually disburse funds
          gateway_ref = gateway.disburse(
            amount_cents: loan.amount_cents,
            recipient: loan.user
          )
          
          # Update loan state
          loan.update!(state: "disbursed")
          
          # Create pending payment record
          loan.payments.create!(
            amount_cents: loan.amount_cents,
            state: "pending",
            gateway_ref: gateway_ref,
            posted_at: Time.current
          )
          
          OutboxEvent.publish!(
            name: "loan.disbursed.v1",
            aggregate: loan,
            payload: {
              loan_id: loan.id,
              user_id: loan.user_id,
              amount_cents: loan.amount_cents,
              gateway_ref: gateway_ref,
              disbursed_at: Time.current.iso8601
            },
            headers: {
              correlation_id: correlation_id,
              gateway_ref: gateway_ref
            }
          )
        end
      end

      def reject!(loan, actor:, reason:, correlation_id: SecureRandom.uuid)
        with_transaction_and_lock(loan) do
          guard_can_reject!(loan)
          
          loan.update!(state: "rejected")
          
          OutboxEvent.publish!(
            name: "loan.rejected.v1",
            aggregate: loan,
            payload: {
              loan_id: loan.id,
              user_id: loan.user_id,
              amount_cents: loan.amount_cents,
              term_days: loan.term_days,
              product: loan.product,
              reason: reason,
              rejected_at: Time.current.iso8601
            },
            headers: {
              correlation_id: correlation_id,
              actor_id: actor.id
            }
          )
        end
      end

      def mark_as_paid!(loan, correlation_id: SecureRandom.uuid)
        with_transaction_and_lock(loan) do
          guard_can_mark_as_paid!(loan)
          
          loan.update!(state: "paid")
          
          OutboxEvent.publish!(
            name: "loan.paid.v1",
            aggregate: loan,
            payload: {
              loan_id: loan.id,
              user_id: loan.user_id,
              principal_cents: loan.amount_cents,
              total_paid_cents: loan.amount_cents, # Will be computed from payments in real reconciliation
              paid_at: Time.current.iso8601
            },
            headers: {
              correlation_id: correlation_id
            }
          )
        end
      end

      def mark_as_overdue!(loan, correlation_id: SecureRandom.uuid)
        with_transaction_and_lock(loan) do
          guard_can_mark_as_overdue!(loan)
          
          # Calculate days overdue before changing state
          days_overdue = loan.due_on ? (Time.zone.today - loan.due_on).to_i : 0
          
          loan.update!(state: "overdue")
          
          OutboxEvent.publish!(
            name: "loan.overdue.v1",
            aggregate: loan,
            payload: {
              loan_id: loan.id,
              user_id: loan.user_id,
              principal_cents: loan.amount_cents,
              outstanding_balance_cents: loan.outstanding_balance_cents,
              days_overdue: days_overdue,
              overdue_at: Time.current.iso8601
            },
            headers: {
              correlation_id: correlation_id
            }
          )
        end
      end

      def mark_as_defaulted!(loan, correlation_id: SecureRandom.uuid)
        with_transaction_and_lock(loan) do
          guard_can_mark_as_defaulted!(loan)
          
          loan.update!(state: "defaulted")
          
          OutboxEvent.publish!(
            name: "loan.defaulted.v1",
            aggregate: loan,
            payload: {
              loan_id: loan.id,
              user_id: loan.user_id,
              principal_cents: loan.amount_cents,
              outstanding_balance_cents: loan.outstanding_balance_cents,
              days_overdue: loan.days_overdue,
              defaulted_at: Time.current.iso8601
            },
            headers: {
              correlation_id: correlation_id
            }
          )
        end
      end

      private

      def with_transaction_and_lock(loan)
        Loan.transaction do
          loan.with_lock do
            yield
          end
        end
      end

      def guard_can_approve!(loan)
        unless loan.state_pending?
          raise InvalidStateTransitionError, "Cannot approve loan in state: #{loan.state}"
        end

        unless loan.user.kyc_approved?
          raise GuardFailedError, "User KYC must be approved to approve loan"
        end

        if loan.user.has_overdue_loans?
          raise GuardFailedError, "User has overdue loans, cannot approve new loan"
        end
      end

      def guard_can_reject!(loan)
        unless loan.state_pending?
          raise InvalidStateTransitionError, "Cannot reject loan in state: #{loan.state}"
        end
      end

      def guard_can_disburse!(loan)
        unless loan.state_approved?
          raise InvalidStateTransitionError, "Cannot disburse loan in state: #{loan.state}"
        end
      end

      def guard_can_mark_as_paid!(loan)
        unless loan.outstanding_balance_cents == 0
          raise GuardFailedError, "Cannot mark as paid: outstanding balance is #{loan.outstanding_balance_cents} cents"
        end
      end

      def guard_can_mark_as_overdue!(loan)
        unless loan.state_disbursed?
          raise InvalidStateTransitionError, "Cannot mark as overdue from state: #{loan.state}"
        end

        # Check if loan is actually overdue by business logic
        unless loan.overdue?
          raise GuardFailedError, "Loan is not past due date or has zero balance"
        end
      end

      def guard_can_mark_as_defaulted!(loan)
        unless loan.state_overdue? || loan.state_disbursed?
          raise InvalidStateTransitionError, "Cannot mark as defaulted from state: #{loan.state}"
        end

        # Check if loan is actually overdue by business logic
        days_past_due = loan.due_on ? (Time.zone.today - loan.due_on).to_i : 0
        
        unless days_past_due > 30
          raise GuardFailedError, "Loan has not reached defaulted threshold (#{days_past_due} days overdue)"
        end
      end
    end
  end
end