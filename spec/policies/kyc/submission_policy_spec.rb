# frozen_string_literal: true

require "rails_helper"

RSpec.describe Kyc::SubmissionPolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  permissions :show?, :new?, :create? do
    it "grants access when user owns the record" do
      expect(subject).to permit(user, user)
    end

    it "denies access when user doesn't own the record" do
      expect(subject).not_to permit(user, other_user)
    end

    it "denies access to anonymous users" do
      expect(subject).not_to permit(nil, user)
    end
  end

  permissions :simulate_decision? do
    context "in development environment" do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it "grants access when user owns the record" do
        expect(subject).to permit(user, user)
      end

      it "denies access when user doesn't own the record" do
        expect(subject).not_to permit(user, other_user)
      end
    end

    context "in production environment" do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
      end

      it "denies access even when user owns the record" do
        expect(subject).not_to permit(user, user)
      end
    end

    it "denies access to anonymous users" do
      expect(subject).not_to permit(nil, user)
    end
  end
end
