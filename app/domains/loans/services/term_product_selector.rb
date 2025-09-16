# frozen_string_literal: true

module Loans
  module Services
    class TermProductSelector
      class InvalidTermError < ArgumentError; end

      PRODUCT_MAPPING = {
        1..60 => "micro",
        61..180 => "extended"
      }.freeze

      LONGTERM_VALID_TERMS = [270, 365].freeze

      def self.for(term_days)
        new(term_days).product
      end

      def initialize(term_days)
        @term_days = term_days&.to_i
      end

      def product
        return nil if @term_days.nil?
        
        raise InvalidTermError, "term_days must be positive" if @term_days <= 0

        # Check longterm first (exact values only)
        return "longterm" if LONGTERM_VALID_TERMS.include?(@term_days)

        # Check micro and extended ranges
        PRODUCT_MAPPING.each do |range, product|
          return product if range.cover?(@term_days)
        end

        # If no match found, it's invalid
        raise InvalidTermError, "Invalid term_days: #{@term_days}. Must be 1-60 (micro), 61-180 (extended), or 270/365 (longterm)"
      end
    end
  end
end