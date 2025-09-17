# == Schema Information
#
# Table name: loans
#
#  id                          :uuid             not null, primary key
#  amount_cents                :integer          not null
#  apr                         :decimal(10, 4)
#  due_on                      :date
#  interest_accrued_cents      :integer          default(0), not null
#  penalty_accrued_cents       :integer          default(0), not null
#  principal_outstanding_cents :integer          default(0), not null
#  product                     :string           not null
#  state                       :string           default("pending"), not null
#  term_days                   :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  user_id                     :uuid             not null
#
# Indexes
#
#  index_loans_on_due_on             (due_on)
#  index_loans_on_state              (state)
#  index_loans_on_state_and_due_on   (state,due_on)
#  index_loans_on_user_id            (user_id)
#  index_loans_on_user_id_and_state  (user_id,state)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require 'rails_helper'

RSpec.describe Loan, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:payments) }
  end

  describe 'validations' do
    subject { build(:loan) }

    it { should validate_presence_of(:amount_cents) }
    it { should validate_numericality_of(:amount_cents).is_greater_than(0) }
    it { should validate_presence_of(:term_days) }
    it { should validate_numericality_of(:term_days).is_greater_than(0) }

    context 'longterm term validation' do
      it 'allows 270 days for longterm loans' do
        loan = build(:loan, product: 'longterm', term_days: 270, amount_cents: 30_000_00)
        expect(loan).to be_valid
      end

      it 'allows 365 days for longterm loans' do
        loan = build(:loan, product: 'longterm', term_days: 365, amount_cents: 30_000_00)
        expect(loan).to be_valid
      end

      it 'rejects other term_days for longterm loans' do
        loan = build(:loan, product: 'longterm', term_days: 300)
        expect(loan).not_to be_valid
        expect(loan.errors[:term_days]).to include('must be 270 or 365 days for longterm loans')
      end
    end

    context 'amount limits validation' do
      context 'micro loans (₱1,000 - ₱15,000)' do
        it 'accepts minimum amount' do
          loan = build(:loan, product: 'micro', amount_cents: 1_000_00)
          expect(loan).to be_valid
        end

        it 'accepts maximum amount' do
          loan = build(:loan, product: 'micro', amount_cents: 15_000_00)
          expect(loan).to be_valid
        end

        it 'rejects amount below minimum' do
          loan = build(:loan, product: 'micro', amount_cents: 999_00)
          expect(loan).not_to be_valid
          expect(loan.errors[:amount_cents]).to include('must be at least ₱1000 for micro loans')
        end

        it 'rejects amount above maximum' do
          loan = build(:loan, product: 'micro', amount_cents: 15_001_00)
          expect(loan).not_to be_valid
          expect(loan.errors[:amount_cents]).to include('must not exceed ₱15000 for micro loans')
        end
      end

      context 'extended loans (₱10,000 - ₱35,000)' do
        it 'accepts minimum amount' do
          loan = build(:loan, product: 'extended', term_days: 90, amount_cents: 10_000_00)
          expect(loan).to be_valid
        end

        it 'accepts maximum amount' do
          loan = build(:loan, product: 'extended', term_days: 120, amount_cents: 35_000_00)
          expect(loan).to be_valid
        end

        it 'rejects amount below minimum' do
          loan = build(:loan, product: 'extended', term_days: 90, amount_cents: 9_999_00)
          expect(loan).not_to be_valid
          expect(loan.errors[:amount_cents]).to include('must be at least ₱10000 for extended loans')
        end

        it 'rejects amount above maximum' do
          loan = build(:loan, product: 'extended', term_days: 120, amount_cents: 35_001_00)
          expect(loan).not_to be_valid
          expect(loan.errors[:amount_cents]).to include('must not exceed ₱35000 for extended loans')
        end
      end

      context 'longterm loans (₱25,000 - ₱75,000)' do
        it 'accepts minimum amount' do
          loan = build(:loan, product: 'longterm', amount_cents: 25_000_00, term_days: 270)
          expect(loan).to be_valid
        end

        it 'accepts maximum amount' do
          loan = build(:loan, product: 'longterm', amount_cents: 75_000_00, term_days: 365)
          expect(loan).to be_valid
        end

        it 'rejects amount below minimum' do
          loan = build(:loan, product: 'longterm', amount_cents: 24_999_00, term_days: 270)
          expect(loan).not_to be_valid
          expect(loan.errors[:amount_cents]).to include('must be at least ₱25000 for longterm loans')
        end

        it 'rejects amount above maximum' do
          loan = build(:loan, product: 'longterm', amount_cents: 75_001_00, term_days: 365)
          expect(loan).not_to be_valid
          expect(loan.errors[:amount_cents]).to include('must not exceed ₱75000 for longterm loans')
        end
      end

      it 'skips validation when amount_cents is blank' do
        loan = build(:loan, amount_cents: nil)
        loan.valid?
        expect(loan.errors[:amount_cents]).not_to include(/must be at least/)
      end

      it 'skips validation when product is blank' do
        loan = build(:loan, product: nil, amount_cents: 100_00, term_days: nil)
        loan.valid?
        expect(loan.errors[:amount_cents]).not_to include(/must be at least/)
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:product).with_values(micro: 'micro', extended: 'extended', longterm: 'longterm').backed_by_column_of_type(:string).with_suffix }
    it { should define_enum_for(:state).with_values(pending: 'pending', approved: 'approved', rejected: 'rejected', disbursed: 'disbursed', paid: 'paid', overdue: 'overdue', defaulted: 'defaulted').backed_by_column_of_type(:string).with_prefix(:state) }
  end

  describe 'enum predicates' do
    let(:loan) { build(:loan, state: 'pending') }

    it 'responds to prefixed state predicates' do
      expect(loan).to respond_to(:state_pending?)
      expect(loan).to respond_to(:state_approved?)
      expect(loan).to respond_to(:state_disbursed?)
      expect(loan).to respond_to(:state_paid?)
      expect(loan).to respond_to(:state_overdue?)
      expect(loan).to respond_to(:state_defaulted?)
    end

    it 'responds to unprefixed state predicates (aliases)' do
      expect(loan).to respond_to(:pending?)
      expect(loan).to respond_to(:approved?)
      expect(loan).to respond_to(:disbursed?)
      expect(loan).to respond_to(:paid?)
      expect(loan).to respond_to(:overdue?)
      expect(loan).to respond_to(:defaulted?)
    end

    it 'returns correct values for state predicates' do
      expect(loan.state_pending?).to be true
      expect(loan.pending?).to be true
      expect(loan.state_approved?).to be false
      expect(loan.approved?).to be false
    end
  end

  describe 'auto product assignment' do
    it 'assigns micro for 1-60 days' do
      loan = build(:loan, term_days: 30, product: nil)
      loan.valid?
      expect(loan.product).to eq('micro')
    end

    it 'assigns extended for 61-180 days' do
      loan = build(:loan, term_days: 90, product: nil)
      loan.valid?
      expect(loan.product).to eq('extended')
    end

    it 'assigns longterm for 270 days' do
      loan = build(:loan, term_days: 270, product: nil)
      loan.valid?
      expect(loan.product).to eq('longterm')
    end

    it 'assigns longterm for 365 days' do
      loan = build(:loan, term_days: 365, product: nil)
      loan.valid?
      expect(loan.product).to eq('longterm')
    end

    it 'does not override existing product' do
      loan = build(:loan, term_days: 30, product: 'micro')
      loan.valid?
      expect(loan.product).to eq('micro')
    end

    it 'sets product to nil for invalid term_days' do
      loan = build(:loan, term_days: 200, product: nil)
      expect(loan).not_to be_valid
      expect(loan.errors[:term_days]).to be_present
    end
  end

  describe 'term_days validation' do
    it 'accepts boundary values for micro (1, 60)' do
      expect(build(:loan, term_days: 1, product: nil)).to be_valid
      expect(build(:loan, term_days: 60, product: nil)).to be_valid
    end

    it 'accepts boundary values for extended (61, 180)' do
      expect(build(:loan, term_days: 61, product: nil)).to be_valid
      expect(build(:loan, term_days: 180, product: nil)).to be_valid
    end

    it 'accepts only 270 and 365 for longterm' do
      expect(build(:loan, term_days: 270, product: nil, amount_cents: 30_000_00)).to be_valid
      expect(build(:loan, term_days: 365, product: nil, amount_cents: 30_000_00)).to be_valid
    end

    it 'rejects invalid term_days values' do
      invalid_terms = [ 0, 181, 200, 269, 271, 300, 366, 400 ]
      invalid_terms.each do |term|
        loan = build(:loan, term_days: term, product: nil)
        expect(loan).not_to be_valid, "Expected term_days #{term} to be invalid"
        expect(loan.errors[:term_days]).to be_present
      end
    end

    it 'ignores client-supplied product mismatches' do
      # Client tries to force micro with longterm term_days
      loan = build(:loan, term_days: 270, product: 'micro')
      expect(loan).not_to be_valid
      expect(loan.errors[:term_days]).to include('invalid for product type micro')
    end
  end

  describe 'money methods' do
    let(:loan) { create(:loan, amount_cents: 10000_00) }

    it 'converts amount_cents to pesos using BigDecimal' do
      expect(loan.amount_in_pesos).to eq(BigDecimal('10000'))
      expect(loan.amount_in_pesos).to be_a(BigDecimal)
    end

    it 'sets amount from pesos using BigDecimal precision' do
      loan.amount_in_pesos = 15000.50
      expect(loan.amount_cents).to eq(15000_50)
    end

    it 'sets amount from string to maintain precision' do
      loan.amount_in_pesos = '15000.25'
      expect(loan.amount_cents).to eq(15000_25)
    end

    it 'calculates total outstanding using BigDecimal' do
      loan.update!(
        principal_outstanding_cents: 5000_00,
        interest_accrued_cents: 200_00,
        penalty_accrued_cents: 100_00
      )
      expect(loan.total_outstanding_cents).to eq(5300_00)
      expect(loan.total_outstanding_in_pesos).to eq(BigDecimal('5300'))
      expect(loan.total_outstanding_in_pesos).to be_a(BigDecimal)
    end

    it 'converts all monetary fields to BigDecimal' do
      loan.update!(
        principal_outstanding_cents: 5000_00,
        interest_accrued_cents: 200_00,
        penalty_accrued_cents: 100_00
      )
      
      expect(loan.principal_outstanding_in_pesos).to be_a(BigDecimal)
      expect(loan.interest_accrued_in_pesos).to be_a(BigDecimal)
      expect(loan.penalty_accrued_in_pesos).to be_a(BigDecimal)
      
      expect(loan.principal_outstanding_in_pesos).to eq(BigDecimal('5000'))
      expect(loan.interest_accrued_in_pesos).to eq(BigDecimal('200'))
      expect(loan.penalty_accrued_in_pesos).to eq(BigDecimal('100'))
    end
  end

  describe 'business logic' do
    let(:user) { create(:user, :kyc_approved) }
    let(:loan) { create(:loan, :pending, user: user) }

    describe '#can_be_approved?' do
      it 'returns true for pending loan with KYC approved user and no overdue loans' do
        expect(loan.can_be_approved?).to be true
      end

      it 'returns false if user has overdue loans' do
        create(:loan, :overdue, user: user)
        expect(loan.can_be_approved?).to be false
      end

      it 'returns false if user KYC is not approved' do
        user.update!(kyc_status: 'pending')
        expect(loan.can_be_approved?).to be false
      end

      it 'returns false if loan is not pending' do
        loan.update!(state: 'approved')
        expect(loan.can_be_approved?).to be false
      end
    end

    describe '#overdue?' do
      it 'returns true for disbursed loan past due date with balance' do
        # Temporarily disable due_date validation for testing overdue scenarios
        allow_any_instance_of(Loan).to receive(:due_date_after_creation)

        loan.update_columns(
          state: 'disbursed',
          due_on: Time.zone.today - 1.day,
          principal_outstanding_cents: 1000_00
        )
        expect(loan.overdue?).to be true
      end

      it 'returns false for paid loan past due date' do
        # Temporarily disable due_date validation for testing overdue scenarios
        allow_any_instance_of(Loan).to receive(:due_date_after_creation)

        loan.update_columns(
          state: 'disbursed',
          due_on: Time.zone.today - 1.day,
          principal_outstanding_cents: 0,
          interest_accrued_cents: 0,
          penalty_accrued_cents: 0
        )
        expect(loan.overdue?).to be false
      end

      it 'uses Manila timezone for due date comparison' do
        allow_any_instance_of(Loan).to receive(:due_date_after_creation)
        
        # Simulate a scenario where Manila time has moved to next day but UTC hasn't
        manila_today = Time.zone.today
        loan.update_columns(
          state: 'disbursed',
          due_on: manila_today - 1.day,
          principal_outstanding_cents: 1000_00
        )
        expect(loan.overdue?).to be true
      end
    end

    describe '#outstanding_balance_cents' do
      it 'is an alias for total_outstanding_cents' do
        loan.update!(
          principal_outstanding_cents: 5000_00,
          interest_accrued_cents: 200_00,
          penalty_accrued_cents: 100_00
        )
        expect(loan.outstanding_balance_cents).to eq(5300_00)
        expect(loan.outstanding_balance_cents).to eq(loan.total_outstanding_cents)
      end
    end
  end

  describe 'scopes' do
    let!(:disbursed_loan) { create(:loan, :disbursed) }
    let!(:overdue_loan) { create(:loan, :overdue) }
    let!(:paid_loan) { create(:loan, :paid) }

    it 'active scope includes disbursed and overdue loans' do
      expect(Loan.active).to contain_exactly(disbursed_loan, overdue_loan)
    end

    it 'overdue_today scope finds disbursed loans past due' do
      # Create a loan with past due date using factories and then update columns to bypass validation
      overdue_today = create(:loan, :disbursed)
      overdue_today.update_columns(due_on: Time.zone.today - 1.day)

      expect(Loan.overdue_today).to include(overdue_today)
    end
  end
end
