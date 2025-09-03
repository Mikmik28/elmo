# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # before_action :configure_sign_in_params, only: [:create]

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

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
