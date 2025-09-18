# frozen_string_literal: true

class Admin::DisbursementsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_loan
  before_action :authorize_force_disbursement!

  def create
    @loan.with_lock do
      if @loan.state_approved?
        # Generate unique idempotency key for admin override
        idem_key = "admin-override-#{SecureRandom.uuid}"

        # Use the same disbursement service
        disbursement_service = Payments::Services::DisbursementService::Stub.new
        disbursement_service.request!(
          @loan,
          idem_key: idem_key,
          correlation_id: request.request_id
        )

        # Log the admin action for audit
        AuditLogger.log(
          "force_disburse_loan",
          current_user,
          {
            loan_id: @loan.id,
            previous_state: "approved",
            new_state: "disbursed",
            idempotency_key: idem_key,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          }
        )

        redirect_to admin_loan_path(@loan), notice: "Loan successfully disbursed."

      elsif @loan.state_disbursed?
        redirect_to admin_loan_path(@loan), notice: "Loan is already disbursed."

      else
        redirect_to admin_loan_path(@loan), alert: "Cannot disburse loan in state: #{@loan.state}"
      end
    end

  rescue Loans::Services::LoanState::InvalidStateTransitionError => e
    redirect_to admin_loan_path(@loan), alert: e.message
  rescue => e
    redirect_to admin_loan_path(@loan), alert: "Failed to disburse loan: #{e.message}"
  end

  private

  def set_loan
    @loan = Loan.find(params[:id])
  end

  def authorize_force_disbursement!
    authorize @loan, :force_disburse?
  end

  def admin_loan_path(loan)
    # This would be the admin loan show path - adjust as needed
    admin_root_path
  end
end
