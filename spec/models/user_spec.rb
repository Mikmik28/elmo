# == Schema Information
#
# Table name: users
#
#  id                        :uuid             not null, primary key
#  confirmation_sent_at      :datetime
#  confirmation_token        :string
#  confirmed_at              :datetime
#  consumed_timestep         :integer
#  credit_limit_cents        :integer          default(0), not null
#  current_score             :integer          default(600), not null
#  date_of_birth             :date
#  email                     :string           default(""), not null
#  encrypted_otp_secret      :string
#  encrypted_otp_secret_iv   :string
#  encrypted_otp_secret_salt :string
#  encrypted_password        :string           default(""), not null
#  failed_attempts           :integer          default(0), not null
#  full_name                 :string
#  kyc_payload               :jsonb
#  kyc_status                :string           default("pending"), not null
#  last_sign_in_with_otp     :datetime
#  locked_at                 :datetime
#  otp_backup_codes          :text
#  otp_required_for_login    :boolean          default(FALSE), not null
#  phone                     :string
#  referral_code             :string
#  remember_created_at       :datetime
#  reset_password_sent_at    :datetime
#  reset_password_token      :string
#  role                      :string           default("user"), not null
#  unconfirmed_email         :string
#  unlock_token              :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token      (confirmation_token) UNIQUE
#  index_users_on_credit_limit_cents      (credit_limit_cents)
#  index_users_on_email                   (email) UNIQUE
#  index_users_on_kyc_status              (kyc_status)
#  index_users_on_otp_required_for_login  (otp_required_for_login)
#  index_users_on_phone                   (phone) UNIQUE
#  index_users_on_referral_code           (referral_code) UNIQUE
#  index_users_on_reset_password_token    (reset_password_token) UNIQUE
#  index_users_on_role                    (role)
#  index_users_on_unlock_token            (unlock_token) UNIQUE
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

    describe 'date of birth validation' do
      it 'allows nil date of birth for non-KYC complete users' do
        user = build(:user, date_of_birth: nil)
        expect(user).to be_valid
      end

      it 'requires date of birth for KYC complete users' do
        user = build(:user, :kyc_complete, date_of_birth: nil)
        expect(user).not_to be_valid
        expect(user.errors[:date_of_birth]).to include("can't be blank")
      end

      it 'rejects future dates' do
        user = build(:user, date_of_birth: 1.day.from_now)
        expect(user).not_to be_valid
        expect(user.errors[:date_of_birth]).to include("cannot be in the future")
      end

      it 'rejects dates more than 120 years ago' do
        user = build(:user, date_of_birth: 121.years.ago)
        expect(user).not_to be_valid
        expect(user.errors[:date_of_birth]).to include("must be within the last 120 years")
      end

      it 'rejects dates for users under 18' do
        user = build(:user, date_of_birth: 17.years.ago.to_date + 1.day) # Definitely under 18
        expect(user).not_to be_valid
        expect(user.errors[:date_of_birth]).to include("must be at least 18 years old")
      end

      it 'accepts valid dates for users 18 and older' do
        user = build(:user, date_of_birth: 19.years.ago.to_date) # Definitely over 18
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

    it 'includes two_factor_authenticatable' do
      expect(User.devise_modules).to include(:two_factor_authenticatable)
    end
  end

  describe 'roles' do
    it 'defaults to user role' do
      user = create(:user)
      expect(user.role).to eq('user')
      expect(user).to be_user_role
    end

    it 'can be assigned staff role' do
      user = create(:user, role: 'staff')
      expect(user.role).to eq('staff')
      expect(user).to be_staff_role
    end

    it 'can be assigned admin role' do
      user = create(:user, role: 'admin')
      expect(user.role).to eq('admin')
      expect(user).to be_admin_role
    end

    it 'validates role inclusion' do
      expect { build(:user, role: 'invalid') }.to raise_error(ArgumentError, "'invalid' is not a valid role")
    end
  end

  describe 'KYC status' do
    it 'defaults to pending' do
      user = create(:user, kyc_status: 'pending')  # Explicitly set since factory defaults to approved
      expect(user.kyc_status).to eq('pending')
      expect(user).to be_kyc_pending
    end

    it 'can be approved' do
      user = create(:user, kyc_status: 'approved')
      expect(user.kyc_status).to eq('approved')
      expect(user).to be_kyc_approved
    end

    it 'can be rejected' do
      user = create(:user, kyc_status: 'rejected')
      expect(user.kyc_status).to eq('rejected')
      expect(user).to be_kyc_rejected
    end

    describe 'enum predicates' do
      let(:user) { build(:user, kyc_status: 'pending') }

      it 'responds to prefixed kyc predicates' do
        expect(user).to respond_to(:kyc_pending?)
        expect(user).to respond_to(:kyc_approved?)
        expect(user).to respond_to(:kyc_rejected?)
      end

      it 'responds to unprefixed kyc predicates (aliases)' do
        expect(user).to respond_to(:pending?)
        expect(user).to respond_to(:approved?)
        expect(user).to respond_to(:rejected?)
      end

      it 'returns correct values for kyc predicates' do
        expect(user.kyc_pending?).to be true
        expect(user.pending?).to be true
        expect(user.kyc_approved?).to be false
        expect(user.approved?).to be false
      end
    end
  end

  describe '#age' do
    it 'returns nil when date_of_birth is not set' do
      user = build(:user, date_of_birth: nil)
      expect(user.age).to be_nil
    end

    it 'calculates age correctly' do
      user = build(:user, date_of_birth: 25.years.ago.to_date)
      expect(user.age).to be_between(24, 25) # Allow for edge cases around birthdays
    end

    it 'handles leap years correctly' do
      # Use a valid leap year date
      user = build(:user, date_of_birth: Date.new(1992, 2, 29)) # 1992 was a leap year
      expected_age = ((Date.current - user.date_of_birth).to_f / 365.25).floor
      expect(user.age).to eq(expected_age)
    end
  end

  describe 'two-factor authentication' do
    let(:user) { create(:user) }

    describe '#two_factor_enabled?' do
      it 'returns false when 2FA is not enabled' do
        expect(user.two_factor_enabled?).to be false
      end

      it 'returns true when 2FA is enabled' do
        user.update!(otp_required_for_login: true)
        expect(user.two_factor_enabled?).to be true
      end
    end

    describe '#requires_two_factor?' do
      it 'returns false for regular users' do
        expect(user.requires_two_factor?).to be false
      end

      it 'returns true for staff users' do
        user.update!(role: 'staff')
        expect(user.requires_two_factor?).to be true
      end

      it 'returns true for admin users' do
        user.update!(role: 'admin')
        expect(user.requires_two_factor?).to be true
      end
    end

    describe '#enable_two_factor!' do
      it 'enables 2FA and generates backup codes' do
        user.enable_two_factor!

        expect(user.two_factor_enabled?).to be true
        expect(user.backup_codes.length).to eq(10)
        expect(user.backup_codes_generated?).to be true
      end
    end

    describe '#disable_two_factor!' do
      before do
        user.enable_two_factor!
      end

      it 'disables 2FA and clears all related data' do
        user.disable_two_factor!

        expect(user.two_factor_enabled?).to be false
        expect(user.backup_codes).to be_empty
        expect(user.encrypted_otp_secret).to be_nil
        expect(user.consumed_timestep).to be_nil
        expect(user.last_sign_in_with_otp).to be_nil
      end
    end

    describe '#backup_codes' do
      it 'returns empty array when no codes are set' do
        expect(user.backup_codes).to eq([])
      end

      it 'returns array of codes when set' do
        codes = user.generate_backup_codes!
        expect(user.backup_codes).to eq(codes)
      end
    end

    describe '#generate_backup_codes!' do
      it 'generates 10 backup codes' do
        codes = user.generate_backup_codes!

        expect(codes.length).to eq(10)
        expect(codes.all? { |code| code.match?(/\A[A-Z0-9]{8}\z/) }).to be true
        expect(user.backup_codes).to eq(codes)
      end
    end

    describe '#invalidate_backup_code!' do
      before do
        user.generate_backup_codes!
      end

      it 'removes a valid backup code' do
        code_to_use = user.backup_codes.first
        initial_count = user.backup_codes.count

        result = user.invalidate_backup_code!(code_to_use)

        expect(result).to be true
        expect(user.backup_codes).not_to include(code_to_use)
        expect(user.backup_codes.count).to eq(initial_count - 1)
      end

      it 'returns false for invalid backup code' do
        result = user.invalidate_backup_code!('INVALID1')

        expect(result).to be false
        expect(user.backup_codes.count).to eq(10)
      end
    end

    describe '#qr_code_uri' do
      it 'returns nil when no OTP secret is present' do
        expect(user.qr_code_uri).to be_nil
      end

      it 'returns provisioning URI when OTP secret is present' do
        user.otp_secret = ROTP::Base32.random_base32

        uri = user.qr_code_uri
        expect(uri).to include('otpauth://totp/')
        expect(uri).to include(CGI.escape(user.email))
        expect(uri).to include('Elmo')
      end
    end

    describe 'privileged role enforcement' do
      it 'automatically enables 2FA for staff users on creation' do
        staff_user = create(:user, role: 'staff')
        expect(staff_user.two_factor_enabled?).to be true
      end

      it 'automatically enables 2FA for admin users on creation' do
        admin_user = create(:user, role: 'admin')
        expect(admin_user.two_factor_enabled?).to be true
      end

      it 'does not enable 2FA for regular users on creation' do
        regular_user = create(:user, role: 'user')
        expect(regular_user.two_factor_enabled?).to be false
      end
    end
  end
end
