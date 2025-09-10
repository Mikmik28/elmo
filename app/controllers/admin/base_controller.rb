# frozen_string_literal: true

class Admin::BaseController < ApplicationController
  before_action :ensure_admin_access

  private

  def ensure_admin_access
    authorize :admin_area, :access?
  end
end
