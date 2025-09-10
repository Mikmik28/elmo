# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "KYC functionality" do
    let(:user) { create(:user) }
    
    describe "Active Storage attachments" do
      it "can attach government ID image" do
        user.kyc_gov_id_image.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/sample_id.jpg")),
          filename: "id.jpg",
          content_type: "image/jpeg"
        )
        
        expect(user.kyc_gov_id_image).to be_attached
      end

      it "can attach selfie image" do
        user.kyc_selfie_image.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/sample_selfie.jpg")),
          filename: "selfie.jpg",
          content_type: "image/jpeg"
        )
        
        expect(user.kyc_selfie_image).to be_attached
      end
    end

    describe "validations" do
      context "government ID image" do
        it "validates content type" do
          user.kyc_gov_id_image.attach(
            io: StringIO.new("fake image"),
            filename: "test.txt",
            content_type: "text/plain"
          )
          
          expect(user).not_to be_valid
          expect(user.errors[:kyc_gov_id_image]).to include("must be a PNG or JPEG image")
        end

        it "accepts PNG images" do
          user.kyc_gov_id_image.attach(
            io: StringIO.new("fake png"),
            filename: "test.png",
            content_type: "image/png"
          )
          
          # Content type validation should pass (size validation might fail but that's separate)
          user.valid?
          expect(user.errors[:kyc_gov_id_image]).not_to include("must be a PNG or JPEG image")
        end

        it "accepts JPEG images" do
          user.kyc_gov_id_image.attach(
            io: StringIO.new("fake jpeg"),
            filename: "test.jpg",
            content_type: "image/jpeg"
          )
          
          user.valid?
          expect(user.errors[:kyc_gov_id_image]).not_to include("must be a PNG or JPEG image")
        end
      end

      context "selfie image" do
        it "validates content type" do
          user.kyc_selfie_image.attach(
            io: StringIO.new("fake image"),
            filename: "test.gif",
            content_type: "image/gif"
          )
          
          expect(user).not_to be_valid
          expect(user.errors[:kyc_selfie_image]).to include("must be a PNG or JPEG image")
        end
      end
    end

    describe "#kyc_submitted?" do
      it "returns false when no files are attached" do
        expect(user.kyc_submitted?).to be false
      end

      it "returns false when only one file is attached" do
        user.kyc_gov_id_image.attach(
          io: StringIO.new("fake image"),
          filename: "id.jpg",
          content_type: "image/jpeg"
        )
        
        expect(user.kyc_submitted?).to be false
      end

      it "returns true when both files are attached" do
        user.kyc_gov_id_image.attach(
          io: StringIO.new("fake image"),
          filename: "id.jpg",
          content_type: "image/jpeg"
        )
        user.kyc_selfie_image.attach(
          io: StringIO.new("fake image"),
          filename: "selfie.jpg",
          content_type: "image/jpeg"
        )
        
        expect(user.kyc_submitted?).to be true
      end
    end

    describe "#kyc_complete?" do
      it "returns false when files not submitted" do
        user.kyc_payload = { "test" => "data" }
        expect(user.kyc_complete?).to be false
      end

      it "returns false when payload is missing" do
        user.kyc_gov_id_image.attach(
          io: StringIO.new("fake image"),
          filename: "id.jpg",
          content_type: "image/jpeg"
        )
        user.kyc_selfie_image.attach(
          io: StringIO.new("fake image"),
          filename: "selfie.jpg",
          content_type: "image/jpeg"
        )
        
        expect(user.kyc_complete?).to be false
      end

      it "returns true when both files and payload exist" do
        user.kyc_gov_id_image.attach(
          io: StringIO.new("fake image"),
          filename: "id.jpg",
          content_type: "image/jpeg"
        )
        user.kyc_selfie_image.attach(
          io: StringIO.new("fake image"),
          filename: "selfie.jpg",
          content_type: "image/jpeg"
        )
        user.kyc_payload = { "gov_id_type" => "drivers_license" }
        
        expect(user.kyc_complete?).to be true
      end
    end
  end
end
