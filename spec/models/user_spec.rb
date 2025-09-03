# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  locked_at              :datetime
#  phone                  :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  unconfirmed_email      :string
#  unlock_token           :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'validates presence of email' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'validates uniqueness of email (case insensitive)' do
      create(:user, email: 'user@example.com')
      user = build(:user, email: 'USER@EXAMPLE.COM')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    it 'validates phone format when present' do
      user = build(:user, phone: 'invalid')
      expect(user).not_to be_valid
      expect(user.errors[:phone]).to include('must be a valid phone number')
    end

    it 'allows blank phone' do
      user = build(:user, phone: nil)
      expect(user).to be_valid
    end

    it 'accepts valid phone formats' do
      valid_phones = [ '+639171234567', '09171234567', '+1 (555) 123-4567' ]
      valid_phones.each do |phone|
        user = build(:user, phone: phone)
        expect(user).to be_valid
      end
    end
  end

  describe 'callbacks' do
    it 'normalizes email to lowercase' do
      user = create(:user, email: 'USER@EXAMPLE.COM')
      expect(user.email).to eq('user@example.com')
    end

    it 'strips email whitespace' do
      user = create(:user, email: '  user@example.com  ')
      expect(user.email).to eq('user@example.com')
    end

    it 'normalizes phone number by removing non-digits' do
      user = create(:user, phone: '+63 (917) 123-4567')
      expect(user.phone).to eq('639171234567')
    end
  end

  describe 'Devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes confirmable' do
      expect(User.devise_modules).to include(:confirmable)
    end

    it 'includes lockable' do
      expect(User.devise_modules).to include(:lockable)
    end
  end
end
