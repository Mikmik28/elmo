# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminAreaPolicy, type: :policy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:staff) { create(:user, :staff) }
  let(:admin) { create(:user, :admin) }
  let(:admin_area) { :admin_area }

  permissions :access? do
    context "for a regular user" do
      it "denies access" do
        expect(subject).not_to permit(user, admin_area)
      end
    end

    context "for a staff user" do
      it "denies access" do
        expect(subject).not_to permit(staff, admin_area)
      end
    end

    context "for an admin user" do
      it "grants access" do
        expect(subject).to permit(admin, admin_area)
      end
    end

    context "for an unauthenticated user" do
      it "denies access" do
        expect(subject).not_to permit(nil, admin_area)
      end
    end
  end
end
