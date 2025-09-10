# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    user&.admin_role?
  end

  def show?
    user&.admin_role? || user == record
  end

  def create?
    user&.admin_role?
  end

  def update?
    user&.admin_role? || user == record
  end

  def destroy?
    user&.admin_role? && user != record
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin_role?
        scope.all
      elsif user
        scope.where(id: user.id)
      else
        scope.none
      end
    end
  end
end
