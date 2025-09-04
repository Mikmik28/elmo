# frozen_string_literal: true

# Audit logging service for authentication events
class AuditLogger
  def self.log_authentication_event(event_type, user, request = nil, additional_data = {})
    event_data = {
      event_type: event_type,
      user_id: user&.id,
      user_email: user&.email,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent,
      timestamp: Time.current.in_time_zone("Asia/Manila"),
      additional_data: additional_data
    }

    Rails.logger.info("[AUDIT] #{event_data.to_json}")

    # In a production environment, you might want to:
    # - Send to external logging service (e.g., Splunk, ELK stack)
    # - Store in database audit table
    # - Send to monitoring/alerting system

    event_data
  end

  def self.log_signin(user, request, success: true)
    log_authentication_event(
      success ? "user_signin_success" : "user_signin_failure",
      user,
      request,
      { success: success }
    )
  end

  def self.log_signup(user, request)
    log_authentication_event("user_signup", user, request)
  end

  def self.log_signout(user, request)
    log_authentication_event("user_signout", user, request)
  end

  def self.log_password_reset(user, request)
    log_authentication_event("password_reset_requested", user, request)
  end

  def self.log_account_locked(user, request)
    log_authentication_event("account_locked", user, request)
  end

  def self.log(event_type, user, additional_data = {})
    request_data = {
      ip_address: additional_data[:ip_address],
      user_agent: additional_data[:user_agent]
    }

    log_authentication_event(event_type, user, nil, additional_data.merge(request_data))
  end
end
