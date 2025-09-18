# frozen_string_literal: true

class Api::Loans::DisbursementsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_loan
  before_action :authorize_disbursement!
  before_action :require_idempotency_key

  rescue_from Pundit::NotAuthorizedError, with: :api_not_authorized

  def create
    # Find existing idempotency key
    idem_key = IdempotencyKey.find_by(key: @idempotency_key, scope: "loans/disburse")

    if idem_key
      # Return previous result
      render json: disbursement_response(@loan), status: :created
      return
    end

    # Verify loan is in approved state
    unless @loan.state_approved?
      render json: { error: "Loan must be approved to disburse" }, status: :unprocessable_content
      return
    end

    # Create disbursement service and request disbursement
    disbursement_service = Payments::Services::DisbursementService::Stub.new
    disbursement_service.request!(
      @loan,
      idem_key: @idempotency_key,
      correlation_id: request.request_id
    )

    render json: disbursement_response(@loan), status: :created

  rescue Loans::Services::LoanState::InvalidStateTransitionError => e
    render json: { error: e.message }, status: :unprocessable_content
  rescue => e
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  protected

  # Override Devise's default redirect behavior for API endpoints
  def authenticate_user!
    if user_signed_in?
      super
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def api_not_authorized
    render json: { error: "Forbidden" }, status: :forbidden
  end

  private

  def set_loan
    @loan = Loan.find(params[:id])
  end

  def authorize_disbursement!
    authorize @loan, :disburse?
  end

  def require_idempotency_key
    @idempotency_key = request.headers["Idempotency-Key"]

    if @idempotency_key.blank?
      render json: { error: "Idempotency-Key header is required" }, status: :unprocessable_content
    end
  end

  def disbursement_response(loan)
    # Reload loan to get fresh state
    loan.reload

    # Get the most recent payment (should be the disbursement payment)
    payment = loan.payments.order(:created_at).last

    # Get recent outbox events for this loan
    events = OutboxEvent.where(aggregate_id: loan.id, aggregate_type: "Loan")
                       .where("name LIKE ? OR name = ?", "loan.disbursement%", "loan.disbursed.v1")
                       .order(:created_at)
                       .pluck(:name)

    {
      loan: {
        id: loan.id,
        state: loan.state,
        payment: payment ? {
          id: payment.id,
          state: payment.state,
          gateway_ref: payment.gateway_ref
        } : nil,
        events: events
      }
    }
  end
end
