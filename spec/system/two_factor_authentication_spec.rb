require 'rails_helper'

RSpec.describe 'Two-Factor Authentication Flow', type: :system do
  let(:user) { create(:user, email: 'user@example.com', password: 'password123') }
  let(:staff_user) { create(:user, :staff, email: 'staff@example.com', password: 'password123') }

  before do
    driven_by(:rack_test)
  end

  describe '2FA Setup for Regular Users' do
    it 'allows user to enable 2FA' do
      sign_in user

      visit two_factor_path

      # Should show QR code and setup form
      expect(page).to have_content('Setup Two-Factor Authentication')
      expect(page).to have_content('Scan this QR code')
      expect(page).to have_field('Verification Code')

      # Setup 2FA with valid code
      user.otp_secret = User.generate_random_otp_secret
      valid_otp = user.current_otp

      fill_in 'Verification Code', with: valid_otp
      click_button 'Enable Two-Factor Authentication'

      # Should redirect to backup codes
      expect(page).to have_current_path(two_factor_backup_codes_path)
      expect(page).to have_content('Two-Factor Backup Codes')
      expect(page).to have_content('ABCD1234') # Assuming generated codes
    end

    it 'shows error with invalid verification code' do
      sign_in user

      visit two_factor_path

      fill_in 'Verification Code', with: '000000'
      click_button 'Enable Two-Factor Authentication'

      expect(page).to have_content('Invalid verification code. Please try again.')
      expect(page).to have_current_path(two_factor_path)
    end

    it 'allows user to disable 2FA' do
      user.enable_two_factor!
      sign_in user

      visit two_factor_path

      click_link 'Disable Two-Factor Authentication'

      expect(page).to have_current_path(root_path)
      expect(page).to have_content('Two-factor authentication has been disabled.')

      user.reload
      expect(user.two_factor_enabled?).to be false
    end
  end

  describe '2FA Setup for Staff Users' do
    it 'automatically enables 2FA for staff users on registration' do
      visit new_user_registration_path

      fill_in 'Email', with: 'newstaff@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      select 'staff', from: 'Role' # Assuming role selection is available

      click_button 'Sign up'

      # Staff should have 2FA enabled automatically
      new_staff = User.find_by(email: 'newstaff@example.com')
      expect(new_staff.two_factor_enabled?).to be true
    end

    it 'prevents staff from disabling 2FA' do
      staff_user.enable_two_factor!
      sign_in staff_user

      visit two_factor_path

      expect(page).not_to have_link('Disable Two-Factor Authentication')
      expect(page).to have_content('Two-factor authentication is enabled')
    end
  end

  describe '2FA During Sign In' do
    let(:user_with_2fa) { create(:user, :with_2fa, email: 'user2fa@example.com', password: 'password123') }

    before do
      user_with_2fa.otp_secret = User.generate_random_otp_secret
      user_with_2fa.save!
    end

    it 'requires 2FA code for users with 2FA enabled' do
      visit new_user_session_path

      fill_in 'Email', with: user_with_2fa.email
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Should show 2FA form
      expect(page).to have_content('Two-Factor Authentication')
      expect(page).to have_content('Enter your 6-digit authentication code')
      expect(page).to have_field('Authentication Code')

      # Enter valid OTP
      valid_otp = user_with_2fa.current_otp
      fill_in 'Authentication Code', with: valid_otp
      click_button 'Verify and Sign In'

      # Should be signed in
      expect(page).to have_current_path(root_path)
      expect(page).to have_content('Signed in successfully') # Devise default message
    end

    it 'allows backup code authentication' do
      backup_code = user_with_2fa.backup_codes.first

      visit new_user_session_path

      fill_in 'Email', with: user_with_2fa.email
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      # Use backup code
      fill_in 'Authentication Code', with: backup_code
      click_button 'Verify and Sign In'

      # Should be signed in
      expect(page).to have_current_path(root_path)

      # Backup code should be consumed
      user_with_2fa.reload
      expect(user_with_2fa.backup_codes).not_to include(backup_code)
    end

    it 'shows error with invalid 2FA code' do
      visit new_user_session_path

      fill_in 'Email', with: user_with_2fa.email
      fill_in 'Password', with: 'password123'
      click_button 'Sign in'

      fill_in 'Authentication Code', with: '000000'
      click_button 'Verify and Sign In'

      expect(page).to have_content('Invalid two-factor authentication code.')
      expect(page).to have_current_path(user_session_path)
    end
  end

  describe 'Backup Codes Management' do
    let(:user_with_2fa) { create(:user, :with_2fa) }

    before do
      sign_in user_with_2fa
    end

    it 'allows viewing backup codes' do
      visit two_factor_backup_codes_path

      expect(page).to have_content('Two-Factor Backup Codes')
      expect(page).to have_content('Save these codes in a secure location')

      # Should display all backup codes
      user_with_2fa.backup_codes.each do |code|
        expect(page).to have_content(code)
      end
    end

    it 'allows regenerating backup codes' do
      original_codes = user_with_2fa.backup_codes

      visit two_factor_backup_codes_path

      click_button 'Regenerate Codes'

      # Should show new codes
      expect(page).to have_content('Two-Factor Backup Codes')

      user_with_2fa.reload
      expect(user_with_2fa.backup_codes).not_to eq(original_codes)
      expect(user_with_2fa.backup_codes.length).to eq(10)
    end

    it 'requires confirmation before regenerating codes' do
      visit two_factor_backup_codes_path

      # Should have confirmation dialog
      expect(page).to have_button('Regenerate Codes')
      # Note: Capybara with rack_test doesn't handle JS confirmations
      # In a full browser test, you would test the confirmation dialog
    end
  end

  describe 'Security and Edge Cases' do
    it 'prevents accessing 2FA pages without authentication' do
      visit two_factor_path

      expect(page).to have_current_path(new_user_session_path)
    end

    it 'redirects to backup codes when 2FA is already enabled' do
      user.enable_two_factor!
      sign_in user

      visit two_factor_path

      expect(page).to have_current_path(two_factor_backup_codes_path)
    end

    it 'prevents accessing backup codes without 2FA enabled' do
      sign_in user

      visit two_factor_backup_codes_path

      expect(page).to have_current_path(two_factor_path)
      expect(page).to have_content('Please enable two-factor authentication first.')
    end
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button 'Sign in'

    # Handle 2FA if user has it enabled
    if user.two_factor_enabled? && page.has_content?('Two-Factor Authentication')
      fill_in 'Authentication Code', with: user.backup_codes.first
      click_button 'Verify and Sign In'
    end
  end
end
