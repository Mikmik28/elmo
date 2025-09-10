# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Authorization - Issue Requirements", type: :model do
  describe "user_denied_admin_area" do
    context "when a regular user tries to access admin area" do
      let(:user) { create(:user) }

      it "is denied by AdminAreaPolicy" do
        policy = AdminAreaPolicy.new(user, :admin_area)
        expect(policy.access?).to be false
      end
    end

    context "when a staff user tries to access admin area" do
      let(:staff) { create(:user, :staff) }

      it "is denied by AdminAreaPolicy" do
        policy = AdminAreaPolicy.new(staff, :admin_area)
        expect(policy.access?).to be false
      end
    end

    context "when an unauthenticated user tries to access admin area" do
      it "is denied by AdminAreaPolicy" do
        policy = AdminAreaPolicy.new(nil, :admin_area)
        expect(policy.access?).to be false
      end
    end
  end

  describe "admin_can_manage_audit_dashboard" do
    context "when an admin user accesses the audit dashboard" do
      let(:admin) { create(:user, :admin) }

      it "is allowed by AdminAreaPolicy" do
        policy = AdminAreaPolicy.new(admin, :admin_area)
        expect(policy.access?).to be true
      end

      it "can access UserPolicy index action" do
        policy = UserPolicy.new(admin, User)
        expect(policy.index?).to be true
      end

      it "can manage other users" do
        other_user = create(:user)
        policy = UserPolicy.new(admin, other_user)
        expect(policy.show?).to be true
        expect(policy.update?).to be true
        expect(policy.destroy?).to be true
      end
    end
  end

  describe "policy_scope_scopes_to_owner" do
    let!(:user1) { create(:user, email: "user1@example.com") }
    let!(:user2) { create(:user, email: "user2@example.com") }
    let!(:admin_user) { create(:user, :admin, email: "admin@example.com") }

    context "when a regular user queries the scope" do
      it "only returns their own user record" do
        policy_scope = UserPolicy::Scope.new(user1, User.all)

        expect(policy_scope.resolve).to contain_exactly(user1)
      end
    end

    context "when an admin queries the scope" do
      it "returns all user records" do
        policy_scope = UserPolicy::Scope.new(admin_user, User.all)

        expect(policy_scope.resolve).to contain_exactly(user1, user2, admin_user)
      end
    end

    context "when an unauthenticated user queries the scope" do
      it "returns an empty scope" do
        policy_scope = UserPolicy::Scope.new(nil, User.all)

        expect(policy_scope.resolve).to be_empty
      end
    end
  end
end
