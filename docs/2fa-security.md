# Two-Factor Authentication (2FA) Security Documentation

## Overview

eLMo implements TOTP (Time-based One-Time Password) two-factor authentication to enhance account security. This document outlines the security measures, implementation details, and compliance considerations.

## Security Features

### 1. TOTP Implementation

- **Algorithm**: SHA-1 based TOTP (RFC 6238)
- **Time Window**: 30-second intervals
- **Code Length**: 6 digits
- **Drift Tolerance**: ±30 seconds to account for clock skew

### 2. Secret Management

- **Encryption**: OTP secrets are encrypted using AES-256-GCM
- **Key Storage**: Encryption keys stored in Rails encrypted credentials
- **Database Storage**: Only encrypted secrets stored in database
- **Key Rotation**: Supports credential rotation without user impact

### 3. Backup Codes

- **Generation**: 10 single-use backup codes per user
- **Format**: 8-character alphanumeric codes (uppercase)
- **Storage**: Stored as comma-separated encrypted values
- **Consumption**: Immediate removal upon use (one-time only)
- **Regeneration**: Users can regenerate codes, invalidating old ones

### 4. Role-Based Enforcement

- **Staff Accounts**: 2FA automatically enabled and cannot be disabled
- **Admin Accounts**: 2FA automatically enabled and cannot be disabled
- **Regular Users**: Optional 2FA with ability to enable/disable

## Security Audit Events

The following events are logged for security monitoring:

### Authentication Events

- `two_factor_enabled`: User enables 2FA
- `two_factor_disabled`: User disables 2FA (regular users only)
- `two_factor_success`: Successful 2FA authentication
- `two_factor_failure`: Failed 2FA authentication attempt
- `backup_codes_regenerated`: User regenerates backup codes

### Audit Log Format

```json
{
  "event_type": "two_factor_enabled",
  "user_id": "uuid",
  "user_email": "user@example.com",
  "ip_address": "192.168.1.1",
  "user_agent": "Mozilla/5.0...",
  "timestamp": "2025-09-04T18:00:00+08:00",
  "additional_data": {
    "method": "totp|backup_code"
  }
}
```

## Threat Mitigation

### 1. Brute Force Protection

- **Account Lockout**: Leverages existing Devise lockable strategy
- **Rate Limiting**: Rack::Attack configuration limits authentication attempts
- **Audit Trail**: All failed attempts logged for monitoring

### 2. Session Security

- **2FA Verification**: Required at each login session
- **Session Invalidation**: 2FA changes invalidate existing sessions
- **Remember Me**: Disabled for 2FA-enabled accounts during 2FA flow

### 3. Recovery Mechanisms

- **Backup Codes**: Secure recovery when authenticator unavailable
- **Account Recovery**: Standard password reset disables 2FA for regular users
- **Staff/Admin Recovery**: Requires administrative intervention

## Implementation Security

### 1. Secret Generation

```ruby
# Cryptographically secure random generation
otp_secret = ROTP::Base32.random_base32(32)

# Backup codes use secure random generation
codes = 10.times.map { SecureRandom.alphanumeric(8).upcase }
```

### 2. Timing Attack Prevention

- **Constant Time Validation**: Uses secure comparison for OTP validation
- **Rate Limiting**: Prevents timing-based attacks through rate limiting

### 3. QR Code Security

- **Temporary Generation**: QR codes generated on-demand, not stored
- **Secure Parameters**: Includes issuer and account information
- **No Secret Exposure**: Secrets only shown during initial setup

## Compliance Considerations

### 1. Data Protection

- **GDPR Compliance**: 2FA data included in user data export/deletion
- **Data Minimization**: Only necessary 2FA data stored
- **Retention Policy**: 2FA data removed when accounts deleted

### 2. Access Controls

- **Principle of Least Privilege**: Users can only manage their own 2FA
- **Administrative Controls**: Staff/admin 2FA enforcement
- **Audit Requirements**: Comprehensive logging for compliance

## Deployment Considerations

### 1. Environment Setup

```yaml
# config/credentials.yml.enc
otp_secret_encryption_key: <64-character-hex-key>
```

### 2. Database Migration

- Encrypted storage fields for OTP secrets
- Backup codes stored as encrypted text
- Indexes on 2FA status for performance

### 3. Monitoring

- **Failed Attempts**: Monitor for unusual 2FA failure patterns
- **Backup Code Usage**: Track backup code consumption
- **Mass Enablement**: Monitor for bulk 2FA changes

## User Experience Security

### 1. Setup Flow

1. User navigates to 2FA setup
2. Temporary OTP secret generated (not saved)
3. QR code displayed for scanning
4. User enters verification code
5. Only on successful verification: secret saved and backup codes generated

### 2. Authentication Flow

1. Standard username/password authentication
2. If 2FA enabled: redirect to 2FA input form
3. Accept TOTP code or backup code
4. On success: complete authentication
5. On failure: log attempt and show error

### 3. Recovery Flow

1. User can use backup codes if authenticator unavailable
2. Backup codes immediately consumed upon use
3. Users warned to regenerate codes when running low

## Security Recommendations

### 1. Operational Security

- Regular review of 2FA adoption rates
- Monitor for users with depleted backup codes
- Periodic security awareness training

### 2. Technical Security

- Regular rotation of OTP encryption keys
- Monitoring of authentication failure rates
- Automated alerts for suspicious patterns

### 3. Business Continuity

- Documented procedure for staff/admin 2FA recovery
- Backup administrator access procedures
- Regular testing of recovery procedures

## Version History

- **v1.0** (2025-09-04): Initial 2FA implementation
  - TOTP support with QR code setup
  - Backup codes (10 per user)
  - Role-based enforcement
  - Comprehensive audit logging

## References

- [RFC 6238 - TOTP Algorithm](https://tools.ietf.org/html/rfc6238)
- [RFC 4226 - HOTP Algorithm](https://tools.ietf.org/html/rfc4226)
- [NIST SP 800-63B - Authentication Guidelines](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-63b.pdf)
