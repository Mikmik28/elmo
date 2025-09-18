# frozen_string_literal: true

class Api::LoansController < ApplicationController
  include Pundit::Authorization

  protect_from_forgery with: :null_session
  before_action :authenticate_user!
  before_action :set_loan, only: [ :show ]

  def index
    @loans = current_user.loans.includes(:payments)
    render json: @loans.map { |loan| loan_json(loan) }
  end

  def show
    render json: loan_json(@loan)
  end

  def create
    # Require Idempotency-Key header
    idempotency_key = request.headers["Idempotency-Key"]
    unless idempotency_key.present?
      return render json: {
        error: {
          code: "missing_idempotency_key",
          message: "Idempotency-Key header is required"
        }
      }, status: :unprocessable_content
    end

    # Validate term_days is in short-term range for this endpoint
    term_days = params.dig(:loan, :term_days) || params[:term_days]
    term_days = term_days&.to_i
    if term_days && (term_days < 1 || term_days > 60)
      return render json: {
        error: {
          code: "validation_failed",
          message: "term_days must be 1..60",
          details: [ "term_days" ]
        }
      }, status: :unprocessable_content
    end

    # Check for existing idempotency key
    existing_key = IdempotencyKey.find_by(
      key: idempotency_key,
      scope: "api/loans/create/#{current_user.id}"
    )

    if existing_key&.resource
      # Return existing loan result
      loan = existing_key.resource
      return render json: loan_json_with_decision(loan), status: :created
    end

    # Authorize loan creation
    authorize Loan, :create?

    # Create loan in transaction
    result = nil
    Loan.transaction do
      # Build and validate loan
      @loan = current_user.loans.build(loan_params)

      if @loan.valid?
        @loan.save!

        # Compute credit score synchronously
        scoring_service = Accounts::Services::CreditScoringService.new(current_user)
        score = scoring_service.compute!(persist: true, emit_event: true)

        # Check auto-approval conditions for short-term loans only
        decision = {
          user_score: score,
          score_threshold: Rails.configuration.x.scoring.short_term_min,
          approved: false,
          reason: nil
        }

        if @loan.product == "micro" &&
           current_user.kyc_approved? &&
           score >= Rails.configuration.x.scoring.short_term_min &&
           !current_user.has_overdue_loans?

          # Auto-approve the loan
          begin
            loan_state = Loans::Services::LoanState.new
            loan_state.approve!(@loan, actor: current_user, correlation_id: request.request_id)
            decision[:approved] = true
            decision[:reason] = "auto_approved_micro_loan"
          rescue Loans::Services::LoanState::GuardFailedError, Loans::Services::LoanState::InvalidStateTransitionError => e
            # If approval fails, keep it pending with appropriate reason
            decision[:reason] = "auto_approval_failed"
          end
        elsif !current_user.kyc_approved?
          decision[:reason] = "kyc_not_approved"
        elsif current_user.has_overdue_loans?
          decision[:reason] = "user_has_overdue_loans"
        elsif score < Rails.configuration.x.scoring.short_term_min
          decision[:reason] = "below_score_threshold"
        else
          decision[:reason] = "pending_manual_review"
        end

        # Store idempotency key
        IdempotencyKey.create!(
          key: idempotency_key,
          scope: "api/loans/create/#{current_user.id}",
          resource: @loan
        )

        # Prepare result with decision information
        result = { loan: @loan, decision: decision }
      else
        raise ActiveRecord::Rollback
      end
    end

    if result
      render json: loan_json_with_decision(result[:loan], result[:decision]), status: :created
    else
      render json: error_response(@loan), status: :unprocessable_content
    end
  end

  private

  def loan_params
    # Note: product is NOT permitted - it's computed from term_days
    # Support both direct params and nested loan params for backward compatibility
    if params[:loan].present?
      params.require(:loan).permit(:amount_cents, :term_days)
    else
      params.permit(:amount_cents, :term_days)
    end
  end

  def set_loan
    @loan = current_user.loans.find(params[:id])
  end

  def loan_json(loan)
    {
      id: loan.id,
      product: loan.product,
      term_days: loan.term_days,
      due_on: loan.due_on,
      state: loan.state,
      amount_cents: loan.amount_cents,
      created_at: loan.created_at,
      updated_at: loan.updated_at
    }
  end

  def loan_json_with_decision(loan, decision = nil)
    base = {
      loan: {
        id: loan.id,
        user_id: loan.user_id,
        state: loan.state,
        product: loan.product,
        amount_cents: loan.amount_cents,
        term_days: loan.term_days,
        due_on: loan.due_on
      }
    }

    if decision
      base[:loan][:decision] = decision
    elsif loan.state == "approved"
      # If loan was previously approved, recreate decision info from current score
      current_score = loan.user.current_score
      base[:loan][:decision] = {
        user_score: current_score,
        score_threshold: Rails.configuration.x.scoring.short_term_min,
        approved: true,
        reason: "auto_approved_micro_loan"
      }
    else
      # For pending loans, we can infer decision from state
      current_score = loan.user.current_score
      base[:loan][:decision] = {
        user_score: current_score,
        score_threshold: Rails.configuration.x.scoring.short_term_min,
        approved: false,
        reason: "pending_manual_review"
      }
    end

    base
  end

  def error_response(loan)
    {
      error: {
        code: "validation_failed",
        message: loan.errors.full_messages.first || "Validation failed",
        details: loan.errors.attribute_names.uniq
      }
    }
  end
end
