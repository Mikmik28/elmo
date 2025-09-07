require 'rails_helper'

RSpec.describe '/two_factor', type: :request do
  let(:user) { create(:user) }
  let(:staff_user) { create(:user, :staff) }

  describe 'GET /two_factor' do
    context 'when user is authenticated' do
      before { login_as(user, scope: :user) }

      context 'when 2FA is not enabled' do
        it 'shows the setup page' do
          get two_factor_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include('Setup Two-Factor Authentication')
        end
      end

      context 'when 2FA is already enabled' do
        before do
          user.enable_two_factor!
        end

        it 'redirects to backup codes page' do
          get two_factor_path

          expect(response).to redirect_to(backup_codes_two_factor_path)
        end
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in page' do
        get two_factor_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST /two_factor' do
    let(:otp_secret) { ROTP::Base32.random_base32 }

    before do
      login_as(user, scope: :user)
      user.otp_secret = otp_secret
    end

    context 'with valid OTP code' do
      let(:valid_otp) { ROTP::TOTP.new(otp_secret).now }

      it 'enables 2FA and redirects to backup codes' do
        expect(AuditLogger).to receive(:log).with('two_factor_enabled', user, anything)

        post two_factor_path, params: { otp_secret: otp_secret, otp_code: valid_otp }

        user.reload
        expect(user.two_factor_enabled?).to be true
        expect(user.backup_codes_generated?).to be true
        expect(response).to redirect_to(backup_codes_two_factor_path)
        follow_redirect!
        expect(response.body).to include('Two-factor authentication has been enabled successfully.')
      end
    end

    context 'with invalid OTP code' do
      let(:invalid_otp) { '123456' }

      it 'does not enable 2FA and re-renders setup page' do
        post two_factor_path, params: { otp_secret: otp_secret, otp_code: invalid_otp }

        user.reload
        expect(user.two_factor_enabled?).to be false
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Invalid verification code. Please try again.')
      end
    end
  end

  describe 'DELETE /two_factor' do
    context 'for regular users with 2FA enabled' do
      before do
        login_as(user, scope: :user)
        user.enable_two_factor!
      end

      it 'disables 2FA and redirects to root' do
        expect(AuditLogger).to receive(:log).with('two_factor_disabled', user, anything)

        delete two_factor_path

        user.reload
        expect(user.two_factor_enabled?).to be false
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('Two-factor authentication has been disabled.')
      end
    end

    context 'for staff users' do
      before do
        login_as(staff_user, scope: :user)
        staff_user.enable_two_factor!
      end

      it 'prevents disabling 2FA and redirects with alert' do
        delete two_factor_path

        staff_user.reload
        expect(staff_user.two_factor_enabled?).to be true
        expect(response).to redirect_to(backup_codes_two_factor_path)
      end
    end
  end

  describe 'GET /two_factor/backup_codes' do
    context 'when 2FA is enabled' do
      before do
        login_as(user, scope: :user)
        user.enable_two_factor!
      end

      it 'shows backup codes page' do
        get backup_codes_two_factor_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Two-Factor Backup Codes')
        user.backup_codes.each do |code|
          expect(response.body).to include(code)
        end
      end
    end

    context 'when 2FA is not enabled' do
      before { login_as(user, scope: :user) }

      it 'redirects to 2FA setup with alert' do
        get backup_codes_two_factor_path

        expect(response).to redirect_to(two_factor_path)
        follow_redirect!
        expect(response.body).to include('Please enable two-factor authentication first.')
      end
    end
  end

  describe 'POST /two_factor/regenerate_backup_codes' do
    context 'when 2FA is enabled' do
      before do
        login_as(user, scope: :user)
        user.enable_two_factor!
      end

      it 'regenerates backup codes and logs the event' do
        original_codes = user.backup_codes

        expect(AuditLogger).to receive(:log).with('backup_codes_regenerated', user, anything)

        post regenerate_backup_codes_two_factor_path

        user.reload
        expect(user.backup_codes).not_to eq(original_codes)
        expect(user.backup_codes.length).to eq(10)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Two-Factor Backup Codes')
      end
    end

    context 'when 2FA is not enabled' do
      before { login_as(user, scope: :user) }

      it 'redirects to 2FA setup with alert' do
        post regenerate_backup_codes_two_factor_path

        expect(response).to redirect_to(two_factor_path)
        follow_redirect!
        expect(response.body).to include('Please enable two-factor authentication first.')
      end
    end
  end
end
