# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create test users for development/demo
if Rails.env.development?
  # Create admin user
  admin = User.find_or_create_by!(email: "admin@example.com") do |user|
    user.password = "password123"
    user.password_confirmation = "password123"
    user.full_name = "Admin User"
    user.role = "admin"
    user.kyc_status = "approved"
    user.otp_required_for_login = false
    user.skip_confirmation!
  end

  # Create borrower user
  borrower = User.find_or_create_by!(email: "borrower@example.com") do |user|
    user.password = "password123"
    user.password_confirmation = "password123"
    user.full_name = "Test Borrower"
    user.role = "user"
    user.kyc_status = "approved"
    user.otp_required_for_login = false
    user.skip_confirmation!
  end

  # Create another test user
  other_user = User.find_or_create_by!(email: "other@example.com") do |user|
    user.password = "password123"
    user.password_confirmation = "password123"
    user.full_name = "Another User"
    user.role = "user"
    user.kyc_status = "approved"
    user.otp_required_for_login = false
    user.skip_confirmation!
  end

  # Create sample loans for testing
  unless borrower.loans.exists?
    # Create a pending loan
    borrower.loans.create!(
      amount_cents: 5_000_00,  # ₱5,000
      term_days: 30,
      state: "pending"
    )

    # Create an approved loan ready for disbursement
    borrower.loans.create!(
      amount_cents: 10_000_00,  # ₱10,000
      term_days: 45,
      state: "approved"
    )

    # Create a disbursed loan with payment
    disbursed_loan = borrower.loans.create!(
      amount_cents: 3_000_00,  # ₱3,000
      term_days: 15,
      state: "disbursed"
    )
    
    # Add payment for the disbursed loan
    disbursed_loan.payments.create!(
      amount_cents: 3_000_00,
      state: "pending",
      gateway_ref: "stub-#{borrower.id}-#{Time.current.to_i}",
      posted_at: Time.current
    )
  end

  puts "✅ Development seed data created:"
  puts "   Admin: admin@example.com / password123"
  puts "   Borrower: borrower@example.com / password123 (#{borrower.loans.count} loans)"
  puts "   Other: other@example.com / password123"
end
