# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Loans::Services::TermProductSelector do
  describe '.for' do
    subject { described_class.for(term_days) }

    context 'with micro loan terms (1-60 days)' do
      [ 1, 30, 45, 60 ].each do |days|
        context "with #{days} days" do
          let(:term_days) { days }
          it { is_expected.to eq('micro') }
        end
      end
    end

    context 'with extended loan terms (61-180 days)' do
      [ 61, 90, 120, 150, 180 ].each do |days|
        context "with #{days} days" do
          let(:term_days) { days }
          it { is_expected.to eq('extended') }
        end
      end
    end

    context 'with longterm loan terms (270 or 365 days only)' do
      [ 270, 365 ].each do |days|
        context "with #{days} days" do
          let(:term_days) { days }
          it { is_expected.to eq('longterm') }
        end
      end
    end

    context 'with invalid term_days' do
      [ 0, -1, 181, 200, 269, 271, 300, 366, 400 ].each do |days|
        context "with #{days} days" do
          let(:term_days) { days }

          it 'raises InvalidTermError' do
            expect { subject }.to raise_error(Loans::Services::TermProductSelector::InvalidTermError)
          end
        end
      end
    end

    context 'with nil term_days' do
      let(:term_days) { nil }
      it { is_expected.to be_nil }
    end

    context 'with string term_days' do
      let(:term_days) { '45' }
      it { is_expected.to eq('micro') }
    end

    context 'with float term_days' do
      let(:term_days) { 45.0 }
      it { is_expected.to eq('micro') }
    end
  end

  describe '#product' do
    it 'provides same result as .for class method' do
      expect(described_class.new(45).product).to eq(described_class.for(45))
    end
  end
end
