# frozen_string_literal: true

module Kyc
  class SubmissionPolicy < ApplicationPolicy
    def show?
      user == record
    end

    def new?
      user == record
    end

    def create?
      user == record
    end

    def simulate_decision?
      Rails.env.development? && user == record
    end
  end
end
