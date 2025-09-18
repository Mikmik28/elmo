# frozen_string_literal: true

# Rack::Attack configuration for rate limiting
# See https://github.com/rack/rack-attack for documentation

class Rack::Attack
  # Always allow requests from localhost in development
  safelist("allow-localhost") do |req|
    "127.0.0.1" == req.ip || "::1" == req.ip if Rails.env.development?
  end

  # Rate limiting for authentication endpoints
  # Allow 5 login attempts per IP per minute
  throttle("login_attempts_per_ip", limit: 5, period: 1.minute) do |req|
    if req.path == "/users/sign_in" && req.post?
      req.ip
    end
  end

  # Allow 3 registration attempts per IP per minute
  throttle("registration_attempts_per_ip", limit: 3, period: 1.minute) do |req|
    if req.path == "/users" && req.post?
      req.ip
    end
  end

  # Allow 3 password reset attempts per IP per minute
  throttle("password_reset_attempts_per_ip", limit: 3, period: 1.minute) do |req|
    if req.path == "/users/password" && req.post?
      req.ip
    end
  end

  # Allow 2 KYC submission attempts per IP per hour
  throttle("kyc_submission_attempts_per_ip", limit: 2, period: 1.hour) do |req|
    if req.path == "/kyc" && req.post?
      req.ip
    end
  end

  # Allow 5 loan application attempts per IP per minute
  throttle("loan_application_attempts_per_ip", limit: 5, period: 1.minute) do |req|
    if req.path == "/api/loans" && req.post?
      req.ip
    end
  end

  # General rate limiting: 100 requests per IP per minute
  throttle("general_requests_per_ip", limit: 100, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  # Response for throttled requests
  self.throttled_responder = lambda do |_request|
    retry_after = Rack::Attack.cache.fetch("throttle:next_attempt", expires_in: 1.minute) { 60 }
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [ { error: "Rate limit exceeded. Please try again later." }.to_json ]
    ]
  end
end
