# frozen_string_literal: true

class LoanPolicy < ApplicationPolicy
  def create?
    # Users can only create loans for themselves
    user.present?
  end

  def show?
    # Users can only view their own loans
    user.present? && record.user_id == user.id
  end

  def index?
    # Users can view their own loans
    user.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see their own loans
      scope.where(user_id: user.id)
    end
  end
end