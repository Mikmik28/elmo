# Copilot Chat Prompts (use these patterns)

1. Scan & Propose
   Plan: Add InterestCalculator with BigDecimal half‑up rounding.
   Changes: files + diffs under app/domains/loans/services and matching specs.
   Tests: edge cases (270/365), rounding, negative/zero, large values.
   Follow‑ups: migrations/env.

Prompt:
"Read /docs/elmo-plan.md section 6 (Financial Calculations) and /app/domains/loans/\*.
Generate InterestCalculator (PORO) and unit specs: short/mid/long‑term formulas, half‑up rounding, invalid long‑term terms.
Return a patch and commands to run tests."

2. Idempotent Webhook
   "Add payments/services/reconcile_payment.rb that upserts by gateway_ref, verifies HMAC header, and uses idempotency_keys.
   Provide request spec covering duplicate delivery and gateway timeout retry."

3. State Transitions
   "Implement LoanState#approve!, #disburse!, #mark_as_paid! exactly per /docs/elmo-plan.md §5, emitting outbox events. Include specs."
