class TwoFactorController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_2fa_setup_allowed, only: [ :show, :create, :destroy ]

  def show
    if current_user.two_factor_enabled?
      redirect_to backup_codes_two_factor_path
    else
      @qr_code_uri = current_user.qr_code_uri
      current_user.otp_secret = ROTP::Base32.random_base32
    end
  end

  def create
    current_user.otp_secret = params[:otp_secret]

    if current_user.validate_and_consume_otp!(params[:otp_code])
      current_user.enable_two_factor!
      AuditLogger.log("two_factor_enabled", current_user, {
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      })

      redirect_to backup_codes_two_factor_path, notice: "Two-factor authentication has been enabled successfully."
    else
      flash.now[:alert] = "Invalid verification code. Please try again."
      @qr_code_uri = current_user.qr_code_uri
      render :show, status: :unprocessable_content
    end
  end

  def destroy
    if current_user.requires_two_factor?
      redirect_to two_factor_path, alert: "Two-factor authentication is required for your account role."
    else
      current_user.disable_two_factor!
      AuditLogger.log("two_factor_disabled", current_user, {
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      })

      redirect_to root_path, notice: "Two-factor authentication has been disabled."
    end
  end

  def backup_codes
    unless current_user.two_factor_enabled?
      redirect_to two_factor_path, alert: "Please enable two-factor authentication first."
      return
    end

    @backup_codes = current_user.backup_codes
  end

  def regenerate_backup_codes
    unless current_user.two_factor_enabled?
      redirect_to two_factor_path, alert: "Please enable two-factor authentication first."
      return
    end

    @backup_codes = current_user.generate_backup_codes!
    current_user.save!

    AuditLogger.log("backup_codes_regenerated", current_user, {
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    })

    render :backup_codes
  end

  private

  def ensure_2fa_setup_allowed
    # Staff and admin accounts cannot disable 2FA if it's already enabled
    if current_user.requires_two_factor? && current_user.two_factor_enabled? && action_name == "destroy"
            redirect_to backup_codes_two_factor_path, alert: "Two-factor authentication cannot be disabled for your account role."
    end
  end
end
