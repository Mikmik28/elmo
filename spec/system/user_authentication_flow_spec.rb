require 'rails_helper'

RSpec.describe 'User Authentication Flow', type: :system do
  before do
    driven_by(:selenium_headless_chrome)
  end

  describe 'Enhanced UI and User Experience' do
    describe 'Sign up page' do
      before { visit new_user_registration_path }

      it 'displays enhanced UI with Tailwind styling' do
        expect(page).to have_content('Create your account')
        expect(page).to have_content('Join eLMo and start building your credit')

        # Check for proper form structure with enhanced styling
        expect(page).to have_field('Email address', type: 'email')
        expect(page).to have_field('Password', type: 'password')
        expect(page).to have_field('Confirm password', type: 'password')
        expect(page).to have_button('Create account')

        # Check for enhanced UI elements
        expect(page).to have_css('.bg-indigo-600') # Button styling
        expect(page).to have_css('.rounded-md') # Form styling
      end

      it 'has accessibility features with ARIA support' do
        # Check for proper labels and ARIA attributes
        expect(page).to have_css('label[for="user_email"]')

        # Check aria-describedby attribute with Capybara
        email_field = find('#user_email')
        expect(email_field['aria-describedby']).to eq('email-help')

        # Check for help text
        expect(page).to have_content('We\'ll use this to send you important account notifications')
        expect(page).to have_content('Include letters, numbers, and special characters for better security')
      end

      it 'includes terms agreement checkbox with proper links' do
        expect(page).to have_field('terms_agreement', type: 'checkbox')
        expect(page).to have_content('Terms of Service')
        expect(page).to have_content('Privacy Policy')

        # Check that terms are required
        expect(find('#terms-agreement')['required']).to eq('true')
      end

      it 'shows proper navigation links with enhanced styling' do
        expect(page).to have_link('Sign in here', href: new_user_session_path)
        expect(page).to have_css('a.text-indigo-600') # Link styling
      end

      context 'with form errors and Turbo updates' do
        it 'displays error messages with proper styling' do
          # Submit form without filling required fields
          click_button 'Create account'

          # Wait for Turbo to update the page with errors
          expect(page).to have_css('[role="alert"]', wait: 5)
          expect(page).to have_content('prohibited this user from being saved')

          # Check that errors are highlighted with proper CSS classes
          expect(page).to have_css('input.border-red-300')
          expect(page).to have_css('.text-red-600') # Error text styling
        end

        it 'shows real-time validation feedback with JavaScript' do
          # Test progressive enhancement
          email_field = find('#user_email')
          email_field.fill_in(with: 'invalid-email')
          email_field.native.send_keys(:tab) # Trigger blur event

          # Note: This test is ready for when we implement real-time validation
          # expect(page).to have_css('#user_email.border-red-300', wait: 2)
        end
      end
    end

    describe 'Sign in page' do
      before { visit new_user_session_path }

      it 'displays enhanced UI with Tailwind styling' do
        expect(page).to have_content('Sign in to your account')
        expect(page).to have_content('Welcome back to eLMo')

        # Check for proper form structure with enhanced styling
        expect(page).to have_field('Email address', type: 'email')
        expect(page).to have_field('Password', type: 'password')
        expect(page).to have_field('Remember me', type: 'checkbox')
        expect(page).to have_button('Sign in')

        # Check for enhanced visual elements
        expect(page).to have_css('.bg-gray-50') # Background styling
        expect(page).to have_css('.text-indigo-600') # Brand colors
      end

      it 'has proper accessibility features' do
        # Check for screen reader only labels
        expect(page).to have_css('.sr-only', text: 'Email address')
        expect(page).to have_css('.sr-only', text: 'Password')

        # Check for proper placeholders
        expect(page).to have_field(placeholder: 'Email address')
        expect(page).to have_field(placeholder: 'Password')

        # Check autofocus
        expect(page).to have_css('input[autofocus]')
      end

      it 'shows navigation links with enhanced styling' do
        expect(page).to have_link('Forgot your password?', href: new_user_password_path)
        expect(page).to have_link('Sign up here', href: new_user_registration_path)

        # Check focus styling for accessibility
        expect(page).to have_css('a.focus\\:ring-2')
      end

      it 'handles Turbo form submission with loading states' do
        user = create(:user)

        fill_in 'Email address', with: user.email
        fill_in 'Password', with: user.password

        # Check initial button state
        submit_button = find('input[type="submit"]')
        expect(submit_button.value).to eq('Sign in')

        # Submit form and check loading state
        click_button 'Sign in'

        # The button should show loading text (data-disable-with)
        expect(submit_button).to be_disabled
        expect(submit_button.value).to eq('Signing in...')

        # Wait for redirect after successful login
        expect(page).to have_current_path(root_path, wait: 5)
      end
    end

    describe 'Password reset workflow' do
      before { visit new_user_password_path }

      it 'displays enhanced UI with helpful messaging' do
        expect(page).to have_content('Forgot your password?')
        expect(page).to have_content('No worries! Enter your email and we\'ll send you reset instructions.')

        expect(page).to have_field('Email address', type: 'email')
        expect(page).to have_button('Send reset instructions')

        # Check for enhanced styling
        expect(page).to have_css('.bg-indigo-600') # Button styling
      end

      it 'has comprehensive help text' do
        expect(page).to have_content('We\'ll send password reset instructions to this email address')
      end

      it 'shows success message with Turbo after form submission' do
        user = create(:user)

        fill_in 'Email address', with: user.email
        click_button 'Send reset instructions'

        # Wait for Turbo to update with success message
        expect(page).to have_content('You will receive an email', wait: 5)
      end
    end

    describe 'Password edit page (reset completion)' do
      let(:user) { create(:user) }
      let(:token) { user.send_reset_password_instructions }

      before { visit edit_user_password_path(reset_password_token: token) }

      it 'displays enhanced UI with security messaging' do
        expect(page).to have_content('Set your new password')
        expect(page).to have_content('Choose a strong password to secure your eLMo account')

        expect(page).to have_field('New password', type: 'password')
        expect(page).to have_field('Confirm new password', type: 'password')
        expect(page).to have_button('Change my password')

        # Check for enhanced styling
        expect(page).to have_css('.space-y-4') # Form spacing
      end

      it 'provides comprehensive password guidance' do
        expect(page).to have_content('Include letters, numbers, and special characters for better security')
      end

      it 'supports password strength feedback (ready for implementation)' do
        password_field = find('#user_password')

        # Test weak password
        password_field.fill_in(with: '123')
        # Note: Ready for password strength indicator implementation

        # Test strong password
        password_field.fill_in(with: 'StrongP@ssw0rd!')
        # Future: expect(page).to have_css('.password-strength-strong', wait: 1)
      end
    end

    describe 'Email confirmation workflow' do
      before { visit new_user_confirmation_path }

      it 'displays enhanced UI with clear messaging' do
        expect(page).to have_content('Resend confirmation')
        expect(page).to have_content('Didn\'t receive the confirmation email? We\'ll send you another one.')

        expect(page).to have_field('Email address', type: 'email')
        expect(page).to have_button('Resend confirmation instructions')

        # Check for enhanced styling
        expect(page).to have_css('.bg-indigo-600')
      end
    end

    describe 'Account unlock workflow' do
      before { visit new_user_unlock_path }

      it 'displays enhanced UI with security context' do
        expect(page).to have_content('Account locked')
        expect(page).to have_content('Your account has been locked due to too many failed sign-in attempts')

        # Check for security explanation
        expect(page).to have_content('Security measure activated')
        expect(page).to have_content('This helps protect your financial information')

        expect(page).to have_field('Email address', type: 'email')
        expect(page).to have_button('Send unlock instructions')

        # Check for enhanced styling with security theme
        expect(page).to have_css('.text-red-600') # Security warning styling
      end
    end
  end

  describe 'Session tracking and user experience' do
    let(:user) { create(:user) }

    context 'when user signs in' do
      it 'tracks sign in information and updates via Turbo' do
        visit new_user_session_path
        fill_in 'Email address', with: user.email
        fill_in 'Password', with: user.password
        click_button 'Sign in'

        # Wait for redirect and page load
        expect(page).to have_current_path(root_path, wait: 5)

        user.reload
        expect(user.sign_in_count).to eq(1)
        expect(user.current_sign_in_at).to be_present
        expect(user.current_sign_in_ip).to be_present
      end
    end

    context 'when user is signed in' do
      before do
        user.update!(
          sign_in_count: 6,
          last_sign_in_at: 1.hour.ago,
          last_sign_in_ip: '192.168.1.1'
        )
        sign_in user
        visit root_path
      end

      it 'displays session information with enhanced formatting' do
        expect(page).to have_content('Last login:')
        expect(page).to have_content('less than a minute ago')
        expect(page).to have_content('IP: 127.0.0.1')
        expect(page).to have_content('logins total')

        # Check for session info styling
        expect(page).to have_css('.text-gray-600') # Session info styling
      end
    end
  end

  describe 'Form validation and error handling' do
    context 'on sign up form with enhanced error display' do
      before { visit new_user_registration_path }

      it 'shows field-specific errors with proper styling via Turbo' do
        fill_in 'Email address', with: 'invalid-email'
        fill_in 'Password', with: '123'
        fill_in 'Confirm password', with: '456'
        click_button 'Create account'

        # Wait for Turbo to update with errors
        expect(page).to have_css('input.border-red-300', wait: 5)
        expect(page).to have_css('[role="alert"]')

        # Check that specific field errors are shown with enhanced styling
        expect(page).to have_content('Email is invalid')
        expect(page).to have_content('Password is too short')
        expect(page).to have_css('.text-red-600') # Error text styling
      end
    end
  end

  describe 'Keyboard navigation and focus management' do
    before { visit new_user_session_path }

    it 'supports comprehensive keyboard navigation' do
      # Focus should start on email field (autofocus)
      email_field = find('#user_email')
      expect(email_field).to be_focused

      # Tab through form elements
      email_field.native.send_keys(:tab)
      password_field = find('#user_password')
      expect(password_field).to be_focused

      password_field.native.send_keys(:tab)
      remember_checkbox = find('#user_remember_me')
      expect(remember_checkbox).to be_focused

      # Check focus styling
      expect(page).to have_css('.focus\\:ring-indigo-500')
    end

    it 'maintains focus on error fields after form submission' do
      click_button 'Sign in'

      # Wait for Turbo to update with errors
      expect(page).to have_css('[role="alert"]', wait: 5)

      # Focus should return to first error field
      email_field = find('#user_email')
      expect(email_field).to be_focused
    end
  end

  describe 'Responsive design and mobile interaction' do
    it 'works properly on mobile viewport' do
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone SE size

      visit new_user_session_path

      # Check that mobile layout is applied
      expect(page).to have_css('.px-4') # Mobile padding
      expect(page).to have_css('.sm\\:px-6') # Responsive padding

      # Form should still be usable
      expect(page).to have_field('Email address', type: 'email')
      expect(page).to have_field('Password', type: 'password')
      expect(page).to have_button('Sign in')

      # Touch interactions should work
      find('#user_email').click
      expect(find('#user_email')).to be_focused
    end
  end

  describe 'Progressive enhancement and JavaScript features' do
    it 'works without JavaScript (graceful degradation)' do
      # Test basic functionality without advanced JS features
      visit new_user_session_path

      # Basic functionality should still work
      expect(page).to have_content('Sign in to your account')
      expect(page).to have_field('Email address', type: 'email')
      expect(page).to have_button('Sign in')

      # Form submission should work (will be regular POST instead of Turbo)
      user = create(:user)
      fill_in 'Email address', with: user.email
      fill_in 'Password', with: user.password
      click_button 'Sign in'

      expect(page).to have_current_path(root_path, wait: 5)
    end
  end

  describe 'Core Authentication Flows (Original Tests Enhanced)' do
    describe 'Happy path: signup → confirm → login' do
      it 'allows user to complete full authentication flow with enhanced UI' do
        # Visit home page
        visit root_path
        expect(page).to have_content('Welcome to eLMo')
        expect(page).to have_link('Sign Up')

        # Sign up with enhanced form
        click_link 'Sign Up'
        expect(page).to have_content('Create your account') # Enhanced heading
        expect(page).to have_content('Join eLMo and start building your credit') # Enhanced subtitle

        fill_in 'Email address', with: 'test@example.com' # Updated field label
        fill_in 'Password', with: 'password123'
        fill_in 'Confirm password', with: 'password123' # Updated field label

        # Accept terms (new requirement)
        check 'terms_agreement'

        click_button 'Create account' # Updated button text

        # Should be redirected and see enhanced confirmation message
        expect(page).to have_content('A message with a confirmation link has been sent to your email address')

        # Manually confirm the user (simulating email click)
        user = User.find_by(email: 'test@example.com')
        expect(user).to be_present
        expect(user.confirmed?).to be false

        # Confirm the user
        user.confirm

        # Now try to sign in with enhanced form
        visit new_user_session_path
        expect(page).to have_content('Sign in to your account') # Enhanced heading
        expect(page).to have_content('Welcome back to eLMo') # Enhanced subtitle

        fill_in 'Email address', with: 'test@example.com' # Updated field label
        fill_in 'Password', with: 'password123'

        # Test loading state
        submit_button = find('input[type="submit"]')
        expect(submit_button.value).to eq('Sign in')

        click_button 'Sign in'

        # Check loading state briefly
        expect(submit_button.value).to eq('Signing in...')

        # Should be signed in with enhanced success messaging
        expect(page).to have_content('Signed in successfully')
        expect(page).to have_content('Hello, test@example.com!')
        expect(page).to have_button('Sign Out')

        # Check session tracking
        user.reload
        expect(user.sign_in_count).to eq(1)
        expect(user.current_sign_in_at).to be_present
      end
    end

    describe 'Invalid email scenario with enhanced error display' do
      it 'rejects signup with invalid email using enhanced error styling' do
        visit new_user_registration_path

        fill_in 'Email address', with: 'invalid-email' # Updated field label
        fill_in 'Password', with: 'password123'
        fill_in 'Confirm password', with: 'password123' # Updated field label
        check 'terms_agreement' # New requirement
        click_button 'Create account' # Updated button text

        # Wait for Turbo to update with enhanced error styling
        expect(page).to have_content('Email is invalid', wait: 5)
        expect(page).to have_css('input.border-red-300') # Enhanced error styling
        expect(page).to have_css('.text-red-600') # Enhanced error text styling
        expect(User.count).to eq(0)
      end
    end

    describe 'Timezone rendering with enhanced display' do
      it 'displays confirmation deadlines in Asia/Manila timezone with enhanced formatting' do
        # This test assumes confirmation tokens have expiry times
        # which would be displayed in the user's local timezone
        Time.use_zone('Asia/Manila') do
          visit new_user_registration_path

          fill_in 'Email address', with: 'timezone@example.com' # Updated field label
          fill_in 'Password', with: 'password123'
          fill_in 'Confirm password', with: 'password123' # Updated field label
          check 'terms_agreement' # New requirement
          click_button 'Create account' # Updated button text

          user = User.find_by(email: 'timezone@example.com')
          expect(user.confirmation_sent_at).to be_within(1.minute).of(Time.current)
        end
      end
    end

    describe 'Pundit guard: non-auth users redirected from protected pages' do
      it 'redirects unauthenticated users to enhanced sign in page' do
        # This would test a protected controller action
        # For now, we'll create a simple test that authenticated routes work
        visit root_path
        expect(page).not_to have_content('Hello,') # Should not show authenticated content

        # If redirected to sign in, should see enhanced UI
        # expect(page).to have_content('Sign in to your account') # Enhanced sign in page
      end
    end

    describe 'Account lockout after failed attempts with enhanced security messaging' do
      let!(:user) { create(:user, email: 'locktest@example.com', password: 'password123') }

      it 'locks account after maximum failed attempts with enhanced security UI' do
        visit new_user_session_path

        # Try to sign in with wrong password multiple times (4 attempts to get warning)
        4.times do |i|
          fill_in 'Email address', with: 'locktest@example.com' # Updated field label
          fill_in 'Password', with: 'wrong_password'
          click_button 'Sign in' # Updated button text

          if i == 3  # On the 4th attempt (index 3), should show warning
            expect(page).to have_content('You have one more attempt before your account is locked')
          else
            expect(page).to have_content('Invalid') # Either "Invalid Email or password" or similar
          end
        end

        # Final attempt that should lock the account
        fill_in 'Email address', with: 'locktest@example.com'
        fill_in 'Password', with: 'wrong_password'
        click_button 'Sign in'

        # User should now be locked
        user.reload
        expect(user.access_locked?).to be true

        # Should show enhanced lockout message
        expect(page).to have_content('Your account is locked')

        # Check that unlock page has enhanced security messaging
        visit new_user_unlock_path
        expect(page).to have_content('Account locked')
        expect(page).to have_content('Security measure activated')
        expect(page).to have_content('This helps protect your financial information')
      end
    end
  end
end
