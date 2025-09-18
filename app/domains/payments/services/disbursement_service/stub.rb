# frozen_string_literal: true

module Payments
  module Services
    module DisbursementService
      class Stub
        def request!(loan, idem_key:, correlation_id: SecureRandom.uuid)
          # Guard: loan must be approved
          unless loan.state_approved?
            raise Loans::Services::LoanState::InvalidStateTransitionError,
                  "Cannot disburse loan in state: #{loan.state}"
          end

          # Emit disbursement requested event
          OutboxEvent.publish!(
            name: "loan.disbursement_requested.v1",
            aggregate: loan,
            payload: {
              loan_id: loan.id,
              amount_cents: loan.amount_cents,
              correlation_id: correlation_id
            },
            headers: {
              correlation_id: correlation_id
            }
          )

          # Call the loan state service to handle disbursement
          Loans::Services::LoanState.new.disburse!(
            loan,
            gateway: self,
            idem_key: idem_key,
            correlation_id: correlation_id
          )
        end

        # Gateway contract method called by LoanState#disburse!
        def disburse(loan)
          # Return deterministic transaction reference for stub
          "stub-#{loan.user.id}-#{Time.current.to_i}"
        end
      end
    end
  end
end
