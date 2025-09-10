# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  prepend_before_action :authenticate_with_two_factor, only: [ :create ]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  def create
    super do |resource|
      if resource.persisted?
        AuditLogger.log_signin(resource, request, success: true)
      end
    end
  rescue StandardError => e
    AuditLogger.log_signin(nil, request, success: false)
    raise e
  end

  # DELETE /resource/sign_out
  def destroy
    current_user_for_audit = current_user
    super do
      AuditLogger.log_signout(current_user_for_audit, request)
    end
  end

  protected

  def authenticate_with_two_factor
    return unless params[:user] && params[:user][:email].present?

    user = User.find_by(email: params[:user][:email].downcase.strip)
    return unless user&.valid_password?(params[:user][:password])

    if user.otp_required_for_login?
      if params[:user][:otp_attempt].present?
        if user.validate_and_consume_otp!(params[:user][:otp_attempt]) ||
           user.invalidate_backup_code!(params[:user][:otp_attempt])
          user.update!(last_sign_in_with_otp: Time.current)
          AuditLogger.log("two_factor_success", user, {
            ip_address: request.remote_ip,
            user_agent: request.user_agent,
            method: params[:user][:otp_attempt].length == 8 ? "backup_code" : "totp"
          })
          nil
        else
          AuditLogger.log("two_factor_failure", user, {
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          })
          flash.now[:alert] = "Invalid two-factor authentication code."
          self.resource = resource_class.new(sign_in_params)
          render :new, status: :unprocessable_content
          nil
        end
      else
        # Show 2FA form
        self.resource = user
        render "users/sessions/two_factor", status: :ok
        nil
      end
    end
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :otp_attempt ])
  end
end
