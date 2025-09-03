require 'rails_helper'

RSpec.describe 'User Authentication', type: :request do
  describe 'User Registration' do
    it 'creates a new user with valid attributes' do
      expect {
        post user_registration_path, params: {
          user: {
            email: 'test@example.com',
            password: 'password123',
            password_confirmation: 'password123'
          }
        }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)
      user = User.last
      expect(user.email).to eq('test@example.com')
      expect(user.confirmed?).to be false
    end

    it 'rejects invalid email' do
      expect {
        post user_registration_path, params: {
          user: {
            email: 'invalid-email',
            password: 'password123',
            password_confirmation: 'password123'
          }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Email is invalid')
    end

    it 'rejects password confirmation mismatch' do
      expect {
        post user_registration_path, params: {
          user: {
            email: 'test@example.com',
            password: 'password123',
            password_confirmation: 'different_password'
          }
        }
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Password confirmation doesn&#39;t match Password")
    end
  end

  describe 'User Sign In' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }

    it 'signs in with valid credentials' do
      post user_session_path, params: {
        user: {
          email: 'test@example.com',
          password: 'password123'
        }
      }

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include('Signed in successfully')
    end

    it 'rejects invalid credentials' do
      post user_session_path, params: {
        user: {
          email: 'test@example.com',
          password: 'wrong_password'
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Invalid Email or password')
    end

    it 'locks account after maximum failed attempts' do
      # Make failed attempts
      5.times do
        post user_session_path, params: {
          user: {
            email: 'test@example.com',
            password: 'wrong_password'
          }
        }
        user.reload
      end

      user.reload
      expect(user.access_locked?).to be true
    end
  end

  describe 'Account Lockout' do
    let!(:locked_user) { create(:user, :locked, email: 'locked@example.com') }

    it 'prevents sign in for locked account' do
      post user_session_path, params: {
        user: {
          email: 'locked@example.com',
          password: 'password123'
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Your account is locked')
    end
  end

  describe 'Email Confirmation' do
    let!(:unconfirmed_user) { create(:user, :unconfirmed, email: 'unconfirmed@example.com') }

    it 'prevents sign in for unconfirmed account' do
      post user_session_path, params: {
        user: {
          email: 'unconfirmed@example.com',
          password: 'password123'
        }
      }

      expect(response).to have_http_status(:found)
      follow_redirect!
      expect(response.body).to include('You have to confirm your email address before continuing')
    end
  end
end
