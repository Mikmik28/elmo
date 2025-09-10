# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::DashboardController, type: :controller do
  describe "GET #index" do
    context "when user is not logged in" do
      it "redirects to sign in page" do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is a regular user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "denies access and redirects with authorization error" do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("You are not authorized to perform this action")
      end
    end

    context "when user is a staff user" do
      let(:staff) { create(:user, role: "staff", otp_required_for_login: false) }

      before { sign_in staff }

      it "denies access and redirects with authorization error" do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("You are not authorized to perform this action")
      end
    end

    context "when user is an admin user" do
      let(:admin) { create(:user, role: "admin", otp_required_for_login: false) }

      before { sign_in admin }

      it "allows access to admin dashboard" do
        get :index
        expect(response).to have_http_status(:success)
      end
    end
  end
end
