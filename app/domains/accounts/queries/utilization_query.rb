# frozen_string_literal: true

module Accounts
  module Queries
    # Computes credit utilization for a given user
    class UtilizationQuery
      def initialize(user)
        @user = user
      end

      def call
        return BigDecimal("1.0") if credit_limit_cents.zero?

        outstanding_principal = BigDecimal(total_outstanding_principal.to_s)
        credit_limit = BigDecimal(credit_limit_cents.to_s)

        outstanding_principal / credit_limit
      end

      private

      attr_reader :user

      def credit_limit_cents
        @user.credit_limit_cents
      end

      def total_outstanding_principal
        @user.loans
             .where(state: %w[disbursed overdue])
             .sum(:principal_outstanding_cents)
      end
    end
  end
end
