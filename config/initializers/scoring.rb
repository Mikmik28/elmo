# frozen_string_literal: true

# Credit scoring configuration
Rails.configuration.x.scoring.weights = {
  payment_history: 0.35,  # on-time rate last 12 months
  utilization:     0.30,  # outstanding_principal / credit_limit
  tenure:          0.10,  # account age
  behavior:        0.15,  # recent loan activity without delinquency
  kyc:             0.10   # bonus when kyc_approved
}

Rails.configuration.x.scoring.bounds = {
  min: 300,
  max: 900,
  base: 600
}

# Feature flags
Rails.configuration.x.scoring.preview_enabled = false    # Allow preview outside dev
Rails.configuration.x.scoring.legacy_delta_mode = false  # Keep old CreditScoreEvent callback OFF by default
