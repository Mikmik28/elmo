require 'rails_helper'

RSpec.describe TwoFactorController, type: :controller do
  let(:user) { create(:user) }
  let(:staff_user) { create(:user, :staff) }
  let(:admin_user) { create(:user, :admin) }

  before do
    sign_in user
  end

  describe 'GET #show' do
    context 'when 2FA is not enabled' do
      it 'renders the setup page' do
        get :show

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:show)
        expect(assigns(:qr_code_uri)).to be_present
      end
    end

    context 'when 2FA is already enabled' do
      before do
        user.enable_two_factor!
      end

      it 'redirects to backup codes page' do
        get :show

        expect(response).to redirect_to(two_factor_backup_codes_path)
      end
    end
  end

  describe 'POST #create' do
    let(:otp_secret) { ROTP::Base32.random_base32 }

    before do
      user.otp_secret = otp_secret
    end

    context 'with valid OTP code' do
      let(:valid_otp) { user.current_otp }

      it 'enables 2FA and redirects to backup codes' do
        expect(AuditLogger).to receive(:log).with('two_factor_enabled', user, anything)

        post :create, params: { otp_secret: otp_secret, otp_code: valid_otp }

        user.reload
        expect(user.two_factor_enabled?).to be true
        expect(user.backup_codes_generated?).to be true
        expect(response).to redirect_to(two_factor_backup_codes_path)
        expect(flash[:notice]).to eq('Two-factor authentication has been enabled successfully.')
      end
    end

    context 'with invalid OTP code' do
      let(:invalid_otp) { '123456' }

      it 'does not enable 2FA and re-renders setup page' do
        expect(AuditLogger).not_to receive(:log)

        post :create, params: { otp_secret: otp_secret, otp_code: invalid_otp }

        user.reload
        expect(user.two_factor_enabled?).to be false
        expect(response).to render_template(:show)
        expect(flash[:alert]).to eq('Invalid verification code. Please try again.')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'for regular users with 2FA enabled' do
      before do
        user.enable_two_factor!
      end

      it 'disables 2FA and redirects to root' do
        expect(AuditLogger).to receive(:log).with('two_factor_disabled', user, anything)

        delete :destroy

        user.reload
        expect(user.two_factor_enabled?).to be false
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Two-factor authentication has been disabled.')
      end
    end

    context 'for staff users' do
      before do
        sign_in staff_user
        staff_user.enable_two_factor!
      end

      it 'prevents disabling 2FA and redirects to backup codes' do
        expect(AuditLogger).not_to receive(:log)

        delete :destroy

        staff_user.reload
        expect(staff_user.two_factor_enabled?).to be true
        expect(response).to redirect_to(two_factor_backup_codes_path)
        expect(flash[:alert]).to eq('Two-factor authentication cannot be disabled for your account role.')
      end
    end

    context 'for admin users' do
      before do
        sign_in admin_user
        admin_user.enable_two_factor!
      end

      it 'prevents disabling 2FA and redirects to backup codes' do
        expect(AuditLogger).not_to receive(:log)

        delete :destroy

        admin_user.reload
        expect(admin_user.two_factor_enabled?).to be true
        expect(response).to redirect_to(two_factor_backup_codes_path)
        expect(flash[:alert]).to eq('Two-factor authentication cannot be disabled for your account role.')
      end
    end
  end

  describe 'GET #backup_codes' do
    context 'when 2FA is enabled' do
      before do
        user.enable_two_factor!
      end

      it 'renders backup codes page' do
        get :backup_codes

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:backup_codes)
        expect(assigns(:backup_codes)).to eq(user.backup_codes)
      end
    end

    context 'when 2FA is not enabled' do
      it 'redirects to 2FA setup with alert' do
        get :backup_codes

        expect(response).to redirect_to(two_factor_path)
        expect(flash[:alert]).to eq('Please enable two-factor authentication first.')
      end
    end
  end

  describe 'POST #regenerate_backup_codes' do
    context 'when 2FA is enabled' do
      before do
        user.enable_two_factor!
      end

      it 'regenerates backup codes and logs the event' do
        original_codes = user.backup_codes

        expect(AuditLogger).to receive(:log).with('backup_codes_regenerated', user, anything)

        post :regenerate_backup_codes

        user.reload
        expect(user.backup_codes).not_to eq(original_codes)
        expect(user.backup_codes.length).to eq(10)
        expect(response).to render_template(:backup_codes)
        expect(assigns(:backup_codes)).to eq(user.backup_codes)
      end
    end

    context 'when 2FA is not enabled' do
      it 'redirects to 2FA setup with alert' do
        post :regenerate_backup_codes

        expect(response).to redirect_to(two_factor_path)
        expect(flash[:alert]).to eq('Please enable two-factor authentication first.')
      end
    end
  end

  context 'when user is not authenticated' do
    before do
      sign_out user
    end

    it 'redirects to sign in page' do
      get :show
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
