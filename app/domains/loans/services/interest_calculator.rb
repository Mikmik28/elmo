# frozen_string_literal: true

module Loans
  module Services
    # Calculates interest based on loan product tier with BigDecimal precision
    # Implements the formulas specified in issue #9 and eLMo financial plan
    class InterestCalculator
      class InvalidTermError < ArgumentError; end

      # Interest rates as BigDecimal for precision
      MICRO_DAILY_RATE = BigDecimal("0.005") # 0.5%
      EXTENDED_MONTHLY_RATE = BigDecimal("0.0349") # 3.49%
      LONGTERM_MONTHLY_RATE = BigDecimal("0.03") # 3.0%
      DAYS_IN_YEAR = BigDecimal("365")
      DAYS_IN_MONTH = BigDecimal("30.44") # Average days per month

      def self.for(amount_cents:, term_days:)
        new(amount_cents: amount_cents, term_days: term_days)
      end

      def initialize(amount_cents:, term_days:)
        @amount_cents = amount_cents
        @term_days = term_days
        @amount_decimal = BigDecimal(amount_cents.to_s) / BigDecimal("100")
        @term_decimal = BigDecimal(term_days.to_s)

        validate_inputs!
        determine_product!
      end

      def total_interest_cents
        @total_interest_cents ||= calculate_interest_cents
      end

      def total_interest_decimal
        @total_interest_decimal ||= BigDecimal(total_interest_cents.to_s) / BigDecimal("100")
      end

      def product
        @product
      end

      def apr
        @apr ||= calculate_apr
      end

      private

      attr_reader :amount_cents, :term_days, :amount_decimal, :term_decimal

      def validate_inputs!
        raise ArgumentError, "amount_cents must be positive" if amount_cents <= 0
        raise ArgumentError, "term_days must be positive" if term_days <= 0
      end

      def determine_product!
        @product = Loans::Services::TermProductSelector.for(term_days)
      rescue Loans::Services::TermProductSelector::InvalidTermError => e
        raise InvalidTermError, e.message
      end

      def calculate_interest_cents
        interest_decimal = case product
        when "micro"
                            calculate_micro_interest
        when "extended"
                            calculate_extended_interest
        when "longterm"
                            calculate_longterm_interest
        else
                            raise InvalidTermError, "Unknown product type: #{product}"
        end

        # Round to 4 decimal places, then convert to cents with banker's rounding
        rounded_interest = interest_decimal.round(4, :half_even)
        (rounded_interest * BigDecimal("100")).round(0, :half_even).to_i
      end

      def calculate_micro_interest
        # Short-term simple interest: amount * (0.5/100) * (term_days/365)
        amount_decimal * MICRO_DAILY_RATE * (term_decimal / DAYS_IN_YEAR)
      end

      def calculate_extended_interest
        # Mid-term monthly interest: amount * (3.49/100) * (term_days/30.44)
        amount_decimal * EXTENDED_MONTHLY_RATE * (term_decimal / DAYS_IN_MONTH)
      end

      def calculate_longterm_interest
        # Long-term monthly interest: amount * (3.0/100) * (term_days/30.44)
        amount_decimal * LONGTERM_MONTHLY_RATE * (term_decimal / DAYS_IN_MONTH)
      end

      def calculate_apr
        # Calculate APR for informational purposes
        # APR = (interest / principal) * (365 / term_days) * 100
        return BigDecimal("0") if amount_decimal.zero? || term_decimal.zero?

        interest_rate = BigDecimal(total_interest_cents.to_s) / BigDecimal(amount_cents.to_s)
        annualized_rate = interest_rate * (DAYS_IN_YEAR / term_decimal)
        (annualized_rate * BigDecimal("100")).round(2, :half_even)
      end
    end
  end
end
