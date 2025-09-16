# frozen_string_literal: true

class LoansController < ApplicationController
  before_action :authenticate_user!

  def new
    @loan = current_user.loans.build
  end

  def create
    @loan = current_user.loans.build(loan_params)
    
    if @loan.save
      redirect_to loan_path(@loan), notice: "Loan created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @loan = current_user.loans.find(params[:id])
  end

  private

  def loan_params
    params.require(:loan).permit(:amount_cents, :term_days)
  end
end