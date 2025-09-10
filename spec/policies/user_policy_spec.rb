# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserPolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:staff) { create(:user, :staff) }
  let(:admin) { create(:user, :admin) }

  permissions :index? do
    context "for a regular user" do
      it "denies access" do
        expect(subject).not_to permit(user, User)
      end
    end

    context "for a staff user" do
      it "denies access" do
        expect(subject).not_to permit(staff, User)
      end
    end

    context "for an admin user" do
      it "grants access" do
        expect(subject).to permit(admin, User)
      end
    end
  end

  permissions :show? do
    context "for a regular user" do
      it "allows viewing their own profile" do
        expect(subject).to permit(user, user)
      end

      it "denies viewing other users' profiles" do
        expect(subject).not_to permit(user, other_user)
      end
    end

    context "for an admin user" do
      it "allows viewing any user profile" do
        expect(subject).to permit(admin, user)
        expect(subject).to permit(admin, other_user)
      end
    end
  end

  permissions :create? do
    context "for a regular user" do
      it "denies access" do
        expect(subject).not_to permit(user, User)
      end
    end

    context "for an admin user" do
      it "grants access" do
        expect(subject).to permit(admin, User)
      end
    end
  end

  permissions :update? do
    context "for a regular user" do
      it "allows updating their own profile" do
        expect(subject).to permit(user, user)
      end

      it "denies updating other users' profiles" do
        expect(subject).not_to permit(user, other_user)
      end
    end

    context "for an admin user" do
      it "allows updating any user profile" do
        expect(subject).to permit(admin, user)
        expect(subject).to permit(admin, other_user)
      end
    end
  end

  permissions :destroy? do
    context "for a regular user" do
      it "denies deleting their own account" do
        expect(subject).not_to permit(user, user)
      end

      it "denies deleting other users' accounts" do
        expect(subject).not_to permit(user, other_user)
      end
    end

    context "for an admin user" do
      it "allows deleting other users' accounts" do
        expect(subject).to permit(admin, user)
      end

      it "denies deleting their own account" do
        expect(subject).not_to permit(admin, admin)
      end
    end
  end

  describe "Scope" do
    subject { UserPolicy::Scope.new(current_user, User.all) }

    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:admin_user) { create(:user, :admin) }

    context "for a regular user" do
      let(:current_user) { user1 }

      it "scopes to only the current user" do
        expect(subject.resolve).to contain_exactly(user1)
      end
    end

    context "for an admin user" do
      let(:current_user) { admin_user }

      it "returns all users" do
        expect(subject.resolve).to contain_exactly(user1, user2, admin_user)
      end
    end

    context "for an unauthenticated user" do
      let(:current_user) { nil }

      it "returns an empty scope" do
        expect(subject.resolve).to be_empty
      end
    end
  end
end
