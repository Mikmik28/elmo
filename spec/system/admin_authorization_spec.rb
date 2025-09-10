# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Authorization", type: :system do
  describe "user_denied_admin_area" do
    context "when a regular user tries to access admin area" do
      let(:user) { create(:user) }

      it "denies access and redirects with error message" do
        sign_in user
        visit admin_root_path

        expect(current_path).to eq(root_path)
        expect(page).to have_content("You are not authorized to perform this action")
      end
    end

    context "when a staff user tries to access admin area" do
      let(:staff) { create(:user, role: "staff", otp_required_for_login: false) }

      it "denies access and redirects with error message" do
        sign_in staff
        visit admin_root_path

        expect(current_path).to eq(root_path)
        expect(page).to have_content("You are not authorized to perform this action")
      end
    end
  end

  describe "admin_can_manage_audit_dashboard" do
    context "when an admin user accesses the audit dashboard" do
      let(:admin) { create(:user, role: "admin", otp_required_for_login: false) }

      it "allows access to the admin dashboard" do
        sign_in admin
        visit admin_dashboard_path

        expect(current_path).to eq(admin_dashboard_path)
        expect(page).to have_content("Admin Dashboard")
      end

      it "allows access to the admin root" do
        sign_in admin
        visit admin_root_path

        expect(current_path).to eq(admin_root_path)
        expect(page).to have_content("Admin Dashboard")
      end
    end
  end
end
