# frozen_string_literal: true

class Api::LoansController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_user!
  before_action :set_loan, only: [:show]

  def index
    @loans = current_user.loans.includes(:payments)
    render json: @loans.map { |loan| loan_json(loan) }
  end

  def show
    render json: loan_json(@loan)
  end

  def create
    @loan = current_user.loans.build(loan_params)
    
    if @loan.save
      render json: loan_json(@loan), status: :created
    else
      render json: error_response(@loan), status: :unprocessable_entity
    end
  end

  private

  def loan_params
    # Note: product is NOT permitted - it's computed from term_days
    params.require(:loan).permit(:amount_cents, :term_days)
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