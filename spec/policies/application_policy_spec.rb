# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationPolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:record) { double }

  permissions :index?, :show?, :create?, :new?, :update?, :edit?, :destroy? do
    it "denies all actions by default" do
      expect(subject).not_to permit(user, record)
    end
  end

  describe "Scope" do
    it "raises NoMethodError when resolve is not implemented" do
      scope = ApplicationPolicy::Scope.new(user, double)

      expect { scope.resolve }.to raise_error(NoMethodError, /You must define #resolve/)
    end
  end
end
