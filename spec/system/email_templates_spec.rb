require "rails_helper"

RSpec.describe "Email Templates", type: :system do
  let(:user) { create(:user, full_name: "Test User") }

  describe "Devise mailer templates" do
    context "confirmation instructions" do
      let(:mail) { Devise::Mailer.confirmation_instructions(user, "fake_token") }

      it "includes brand header and footer" do
        expect(mail.body.encoded).to include("eLMo")
        expect(mail.body.encoded).to include("Your Trusted Financial Partner")
        expect(mail.body.encoded).to include("Empowering your financial journey")
      end

      it "includes Manila timezone timestamp" do
        manila_time = Time.current.in_time_zone("Asia/Manila").strftime("%B %d, %Y at %l:%M %p PHT")
        expect(mail.body.encoded).to include("Sent on #{manila_time}")
      end

      it "has clear CTA button" do
        expect(mail.body.encoded).to include("Confirm My Account")
        expect(mail.body.encoded).to include("cta-button")
      end

      it "includes personalized greeting" do
        expect(mail.body.encoded).to include("Hello Test User!")
      end

      it "includes helpful information boxes" do
        expect(mail.body.encoded).to include("What's next?")
        expect(mail.body.encoded).to include("info-box")
      end

      it "includes fallback link for accessibility" do
        expect(mail.body.encoded).to include("Having trouble?")
        expect(mail.body.encoded).to include("copy and paste this link")
      end
    end

    context "reset password instructions" do
      let(:mail) { Devise::Mailer.reset_password_instructions(user, "fake_token") }

      it "includes security information" do
        expect(mail.body.encoded).to include("Security reminder")
        expect(mail.body.encoded).to include("This link will expire in 6 hours")
      end

      it "has clear CTA button" do
        expect(mail.body.encoded).to include("Reset My Password")
        expect(mail.body.encoded).to include("cta-button")
      end

      it "includes security context" do
        expect(mail.body.encoded).to include("Password Reset Request")
        expect(mail.body.encoded).to include("we never include passwords in emails")
      end
    end

    context "unlock instructions" do
      let(:mail) { Devise::Mailer.unlock_instructions(user, "fake_token") }

      it "explains why account was locked" do
        expect(mail.body.encoded).to include("Account Security Alert")
        expect(mail.body.encoded).to include("multiple unsuccessful sign-in attempts")
        expect(mail.body.encoded).to include("protect your financial information")
      end

      it "includes security tips" do
        expect(mail.body.encoded).to include("Security tips:")
        expect(mail.body.encoded).to include("strong, unique password")
        expect(mail.body.encoded).to include("two-factor authentication")
      end

      it "has clear CTA button" do
        expect(mail.body.encoded).to include("Unlock My Account")
        expect(mail.body.encoded).to include("cta-button")
      end
    end

    context "email changed notification" do
      let(:mail) { Devise::Mailer.email_changed(user) }

      it "includes security details" do
        expect(mail.body.encoded).to include("Email Address Updated")
        expect(mail.body.encoded).to include("Important security information")
      end

      it "includes IP address if available" do
        user.update!(current_sign_in_ip: "192.168.1.1")
        mail_with_ip = Devise::Mailer.email_changed(user)
        expect(mail_with_ip.body.encoded).to include("192.168.1.1")
      end

      it "has security warning" do
        expect(mail.body.encoded).to include("Didn't make this change?")
        expect(mail.body.encoded).to include("contact our support team immediately")
      end
    end

    context "password changed notification" do
      let(:mail) { Devise::Mailer.password_change(user) }

      it "includes timestamp in Manila timezone" do
        manila_time = Time.current.in_time_zone("Asia/Manila").strftime("%B %d, %Y at %l:%M %p PHT")
        expect(mail.body.encoded).to include("Change made on: #{manila_time}")
      end

      it "includes security reminders" do
        expect(mail.body.encoded).to include("Security reminders:")
        expect(mail.body.encoded).to include("Keep your password secure")
        expect(mail.body.encoded).to include("two-factor authentication")
      end

      it "has security alert" do
        expect(mail.body.encoded).to include("Didn't make this change?")
        expect(mail.body.encoded).to include("unauthorized access")
      end
    end
  end

  describe "Email layout consistency" do
    let(:confirmation_mail) { Devise::Mailer.confirmation_instructions(user, "fake_token") }
    let(:reset_mail) { Devise::Mailer.reset_password_instructions(user, "fake_token") }

    it "uses consistent branding across all emails" do
      [ confirmation_mail, reset_mail ].each do |mail|
        expect(mail.body.encoded).to include("eLMo")
        expect(mail.body.encoded).to include("Your Trusted Financial Partner")
        expect(mail.body.encoded).to include("© #{Date.current.year} eLMo. All rights reserved.")
      end
    end

    it "includes responsive design elements" do
      expect(confirmation_mail.body.encoded).to include("max-width: 600px")
      expect(confirmation_mail.body.encoded).to include("@media only screen and (max-width: 600px)")
    end

    it "uses proper email DOCTYPE for compatibility" do
      expect(confirmation_mail.body.encoded).to include('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"')
    end
  end

  describe "Accessibility in emails" do
    let(:mail) { Devise::Mailer.confirmation_instructions(user, "fake_token") }

    it "includes alt text and proper semantic structure" do
      # Check for proper heading structure
      expect(mail.body.encoded).to include("<h2>")

      # Check for proper button styling and accessibility
      expect(mail.body.encoded).to include("text-decoration: none")
      expect(mail.body.encoded).to include("display: inline-block")
    end

    it "has good color contrast for readability" do
      # Check for dark text on light backgrounds
      expect(mail.body.encoded).to include("color: #2d3748")
      expect(mail.body.encoded).to include("background-color: #ffffff")
    end
  end

  describe "Email content quality" do
    let(:mail) { Devise::Mailer.confirmation_instructions(user, "fake_token") }

    it "uses clear, non-technical language" do
      expect(mail.body.encoded).to include("Welcome to eLMo!")
      expect(mail.body.encoded).to include("trusted financial partner")
      expect(mail.body.encoded).to include("quick, transparent access")
    end

    it "includes clear next steps" do
      expect(mail.body.encoded).to include("What's next?")
      expect(mail.body.encoded).to include("complete your profile")
      expect(mail.body.encoded).to include("apply for your first loan")
    end

    it "maintains professional but friendly tone" do
      expect(mail.body.encoded).to include("We're excited to help you")
      expect(mail.body.encoded).to include("Welcome aboard!")
    end
  end
end
