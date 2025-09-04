class AddTwoFactorToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :encrypted_otp_secret, :string
    add_column :users, :encrypted_otp_secret_iv, :string
    add_column :users, :encrypted_otp_secret_salt, :string
    add_column :users, :otp_required_for_login, :boolean, default: false, null: false
    add_column :users, :otp_backup_codes, :text
    add_column :users, :consumed_timestep, :integer
    add_column :users, :last_sign_in_with_otp, :datetime
    add_column :users, :role, :string, default: 'user', null: false

    add_index :users, :otp_required_for_login
    add_index :users, :role
  end
end
