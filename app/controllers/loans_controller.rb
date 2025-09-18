# frozen_string_literal: true

class LoansController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.admin_role?
      @loans = Loan.includes(:user).order(created_at: :desc)
    else
      @loans = current_user.loans.order(created_at: :desc)
    end
  end

  def new
    @loan = current_user.loans.build
  end

  def create
    @loan = current_user.loans.build(loan_params)

    if @loan.save
      redirect_to @loan, notice: "Loan was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    if current_user.admin_role?
      @loan = Loan.find(params[:id])
    else
      @loan = current_user.loans.find(params[:id])
    end
  end

  private

  def loan_params
    params.require(:loan).permit(:amount_cents, :term_days)
  end
end
