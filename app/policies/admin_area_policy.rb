# frozen_string_literal: true

class AdminAreaPolicy < ApplicationPolicy
  def access?
    user&.admin_role? || false
  end
end
