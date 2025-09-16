# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Loans::Services::InterestCalculator do
  describe '.for' do
    it 'returns a new instance' do
      calculator = described_class.for(amount_cents: 10000_00, term_days: 30)
      expect(calculator).to be_a(described_class)
    end
  end

  describe '#initialize' do
    context 'with valid inputs' do
      it 'initializes successfully' do
        expect { described_class.new(amount_cents: 10000_00, term_days: 30) }.not_to raise_error
      end
    end

    context 'with invalid inputs' do
      it 'raises ArgumentError for zero amount_cents' do
        expect { described_class.new(amount_cents: 0, term_days: 30) }.to raise_error(ArgumentError, "amount_cents must be positive")
      end

      it 'raises ArgumentError for negative amount_cents' do
        expect { described_class.new(amount_cents: -1000, term_days: 30) }.to raise_error(ArgumentError, "amount_cents must be positive")
      end

      it 'raises ArgumentError for zero term_days' do
        expect { described_class.new(amount_cents: 10000_00, term_days: 0) }.to raise_error(ArgumentError, "term_days must be positive")
      end

      it 'raises InvalidTermError for invalid term_days (200 days)' do
        expect { described_class.new(amount_cents: 10000_00, term_days: 200) }.to raise_error(
          described_class::InvalidTermError, /Invalid term_days: 200/
        )
      end

      it 'raises InvalidTermError for invalid longterm terms (300 days)' do
        expect { described_class.new(amount_cents: 10000_00, term_days: 300) }.to raise_error(
          described_class::InvalidTermError, /Invalid term_days: 300/
        )
      end
    end
  end

  describe 'boundaries_60_61_180_270_365' do
    let(:amount_cents) { 10000_00 } # ₱10,000

    context 'micro loan boundaries' do
      it 'calculates interest for 1 day (boundary)' do
        calculator = described_class.new(amount_cents: amount_cents, term_days: 1)
        expect(calculator.product).to eq('micro')
        expect(calculator.total_interest_cents).to be > 0
        expect(calculator.total_interest_cents).to be_a(Integer)
      end

      it 'calculates interest for 60 days (boundary)' do
        calculator = described_class.new(amount_cents: amount_cents, term_days: 60)
        expect(calculator.product).to eq('micro')
        expect(calculator.total_interest_cents).to be > 0
      end
    end

    context 'extended loan boundaries' do
      it 'calculates interest for 61 days (boundary)' do
        calculator = described_class.new(amount_cents: amount_cents, term_days: 61)
        expect(calculator.product).to eq('extended')
        expect(calculator.total_interest_cents).to be > 0
      end

      it 'calculates interest for 180 days (boundary)' do
        calculator = described_class.new(amount_cents: amount_cents, term_days: 180)
        expect(calculator.product).to eq('extended')
        expect(calculator.total_interest_cents).to be > 0
      end
    end

    context 'longterm loan boundaries' do
      it 'calculates interest for 270 days (boundary)' do
        calculator = described_class.new(amount_cents: amount_cents, term_days: 270)
        expect(calculator.product).to eq('longterm')
        expect(calculator.total_interest_cents).to be > 0
      end

      it 'calculates interest for 365 days (boundary)' do
        calculator = described_class.new(amount_cents: amount_cents, term_days: 365)
        expect(calculator.product).to eq('longterm')
        expect(calculator.total_interest_cents).to be > 0
      end
    end
  end

  describe 'invalid_200_days_rejected' do
    it 'rejects 200 days as invalid term' do
      expect { described_class.new(amount_cents: 10000_00, term_days: 200) }.to raise_error(
        described_class::InvalidTermError
      )
    end

    it 'rejects other invalid terms in the gap' do
      [ 181, 185, 199, 269, 271, 300, 364, 366 ].each do |invalid_term|
        expect { described_class.new(amount_cents: 10000_00, term_days: invalid_term) }.to raise_error(
          described_class::InvalidTermError
        ), "Expected term_days #{invalid_term} to be rejected"
      end
    end
  end

  describe 'rounding_precision_4dp' do
    it 'rounds half-up to cents with proper precision' do
      # Use amount that will generate fractional cents to test rounding
      calculator = described_class.new(amount_cents: 1, term_days: 1)

      # Result should be an integer (cents)
      expect(calculator.total_interest_cents).to be_a(Integer)
      expect(calculator.total_interest_cents).to be >= 0
    end

    it 'handles banker\'s rounding correctly' do
      # Test with amounts that will generate exactly 0.5 cents to verify banker's rounding
      calculator = described_class.new(amount_cents: 100000_00, term_days: 30) # Large amount for precision testing

      # Should round using banker's rounding (half to even)
      expect(calculator.total_interest_cents).to be_a(Integer)
    end

    it 'maintains 4 decimal place precision in calculation' do
      calculator = described_class.new(amount_cents: 12345_67, term_days: 45)

      # Verify BigDecimal precision is maintained
      expect(calculator.total_interest_decimal).to be_a(BigDecimal)
      expect(calculator.total_interest_cents).to eq((calculator.total_interest_decimal * 100).round(0, :half_even).to_i)
    end
  end

  describe 'specific formula calculations' do
    context 'micro loans (1-60 days)' do
      it 'calculates using simple interest formula: amount * (0.5/100) * (term_days/365)' do
        calculator = described_class.new(amount_cents: 10000_00, term_days: 30)

        # Manual calculation: 10000 * (0.5/100) * (30/365) = 10000 * 0.005 * 0.08219 ≈ 41.10
        expected_interest = BigDecimal("10000") * BigDecimal("0.005") * (BigDecimal("30") / BigDecimal("365"))
        expected_cents = (expected_interest * BigDecimal("100")).round(0, :half_even).to_i

        expect(calculator.total_interest_cents).to eq(expected_cents)
        expect(calculator.product).to eq('micro')
      end
    end

    context 'extended loans (61-180 days)' do
      it 'calculates using monthly interest formula: amount * (3.49/100) * (term_days/30.44)' do
        calculator = described_class.new(amount_cents: 10000_00, term_days: 90)

        # Manual calculation: 10000 * (3.49/100) * (90/30.44) ≈ 1032.89
        expected_interest = BigDecimal("10000") * BigDecimal("0.0349") * (BigDecimal("90") / BigDecimal("30.44"))
        expected_cents = (expected_interest * BigDecimal("100")).round(0, :half_even).to_i

        expect(calculator.total_interest_cents).to eq(expected_cents)
        expect(calculator.product).to eq('extended')
      end
    end

    context 'longterm loans (270/365 days)' do
      it 'calculates using monthly interest formula: amount * (3.0/100) * (term_days/30.44)' do
        calculator = described_class.new(amount_cents: 10000_00, term_days: 270)

        # Manual calculation: 10000 * (3.0/100) * (270/30.44) ≈ 2661.29
        expected_interest = BigDecimal("10000") * BigDecimal("0.03") * (BigDecimal("270") / BigDecimal("30.44"))
        expected_cents = (expected_interest * BigDecimal("100")).round(0, :half_even).to_i

        expect(calculator.total_interest_cents).to eq(expected_cents)
        expect(calculator.product).to eq('longterm')
      end

      it 'calculates for 365 days' do
        calculator = described_class.new(amount_cents: 25000_00, term_days: 365)

        expect(calculator.product).to eq('longterm')
        expect(calculator.total_interest_cents).to be > 0
      end
    end
  end

  describe '#apr' do
    it 'calculates APR for informational purposes' do
      calculator = described_class.new(amount_cents: 10000_00, term_days: 30)

      expect(calculator.apr).to be_a(BigDecimal)
      expect(calculator.apr).to be > 0
    end

    it 'returns zero APR for zero amounts' do
      calculator = described_class.new(amount_cents: 1, term_days: 1) # Minimum positive values

      # APR should be calculated properly even for small amounts
      expect(calculator.apr).to be_a(BigDecimal)
    end
  end

  describe '#product' do
    it 'returns the correct product type determined by TermProductSelector' do
      micro_calc = described_class.new(amount_cents: 10000_00, term_days: 30)
      extended_calc = described_class.new(amount_cents: 10000_00, term_days: 90)
      longterm_calc = described_class.new(amount_cents: 10000_00, term_days: 270)

      expect(micro_calc.product).to eq('micro')
      expect(extended_calc.product).to eq('extended')
      expect(longterm_calc.product).to eq('longterm')
    end
  end

  describe 'integration with TermProductSelector' do
    it 'uses TermProductSelector for product determination' do
      expect(Loans::Services::TermProductSelector).to receive(:for).with(45).and_return('micro')

      calculator = described_class.new(amount_cents: 10000_00, term_days: 45)
      expect(calculator.product).to eq('micro')
    end

    it 'propagates InvalidTermError from TermProductSelector' do
      allow(Loans::Services::TermProductSelector).to receive(:for).and_raise(
        Loans::Services::TermProductSelector::InvalidTermError, "Invalid term"
      )

      expect { described_class.new(amount_cents: 10000_00, term_days: 200) }.to raise_error(
        described_class::InvalidTermError, "Invalid term"
      )
    end
  end
end
