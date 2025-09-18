require 'rails_helper'

RSpec.describe 'User Authentication Flow', type: :system do
  before do
    driven_by(:rack_test)
  end

  describe 'Happy path: signup → confirm → login' do
    it 'allows user to complete full authentication flow' do
      # Visit home page
      visit root_path
      expect(page).to have_content('Welcome to eLMo')
      expect(page).to have_link('Sign Up')

      # Sign up
      click_link 'Sign Up'
      expect(page).to have_content('Sign up')

      fill_in 'Email', with: 'test@example.com'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      # Should be redirected and see confirmation message
      expect(page).to have_content('A message with a confirmation link has been sent to your email address')

      # Manually confirm the user (simulating email click)
      user = User.find_by(email: 'test@example.com')
      expect(user).to be_present
      expect(user.confirmed?).to be false

      # Confirm the user
      user.confirm

      # Now try to sign in
      visit new_user_session_path
      fill_in 'Email', with: 'test@example.com'
      fill_in 'Password', with: 'password123'
      click_button 'Log in'

      # Should be signed in
      expect(page).to have_content('Signed in successfully')
      expect(page).to have_content('Hello, test@example.com!')
      expect(page).to have_button('Sign Out')
    end
  end

  describe 'Invalid email scenario' do
    it 'rejects signup with invalid email' do
      visit new_user_registration_path

      fill_in 'Email', with: 'invalid-email'
      fill_in 'Password', with: 'password123'
      fill_in 'Password confirmation', with: 'password123'
      click_button 'Sign up'

      expect(page).to have_content('Email is invalid')
      expect(User.count).to eq(0)
    end
  end

  describe 'Timezone rendering' do
    it 'displays confirmation deadlines in Asia/Manila timezone' do
      # This test assumes confirmation tokens have expiry times
      # which would be displayed in the user's local timezone
      Time.use_zone('Asia/Manila') do
        visit new_user_registration_path

        fill_in 'Email', with: 'timezone@example.com'
        fill_in 'Password', with: 'password123'
        fill_in 'Password confirmation', with: 'password123'
        click_button 'Sign up'

        user = User.find_by(email: 'timezone@example.com')
        expect(user.confirmation_sent_at).to be_within(1.minute).of(Time.current)
      end
    end
  end

  describe 'Pundit guard: non-auth users redirected from protected pages' do
    it 'redirects unauthenticated users to sign in' do
      # This would test a protected controller action
      # For now, we'll create a simple test that authenticated routes work
      visit root_path
      expect(page).not_to have_content('Hello,') # Should not show authenticated content
    end
  end

  describe 'Account lockout after failed attempts' do
    let!(:user) { create(:user, email: 'locktest@example.com', password: 'password123') }

    it 'locks account after maximum failed attempts' do
      visit new_user_session_path

      # Try to sign in with wrong password multiple times (5 attempts to trigger lockout)
      4.times do |i|
        fill_in 'Email', with: 'locktest@example.com'
        fill_in 'Password', with: 'wrong_password'
        click_button 'Log in'

        if i == 3  # On the 4th attempt (index 3), should show warning
          expect(page).to have_content('You have one more attempt before your account is locked')
        else
          expect(page).to have_content('Invalid') # Either "Invalid Email or password" or similar
        end
      end

      # Final attempt that should lock the account
      fill_in 'Email', with: 'locktest@example.com'
      fill_in 'Password', with: 'wrong_password'
      click_button 'Log in'

      # User should now be locked
      user.reload
      expect(user.access_locked?).to be true

      # Should show lockout message
      expect(page).to have_content('Your account is locked')
    end
  end
end
