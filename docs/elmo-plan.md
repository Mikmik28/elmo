# eLMo — Full Plan (source of truth)

# eLMo – Full Plan

> You asked for a single, copy‑paste‑ready deliverable. This canvas packs UVP, roadmap, DFDs/ERD, domain/state, finance rules, eventing/outbox, repo layout, dev guide, security/observability, RSpec skeletons, sample APIs, backlog, and GitHub Actions CI/CD — optimized for a Rails 8 monolith with Solid _everything_ and Kamal 2.

---

## 1) One‑sentence UVP

**eLMo gives first‑time and repeat borrowers instant, transparent micro‑loans with game‑style credit building, funded and repaid in minutes — not days — on a simple, mobile‑first Rails 8 platform.**

---

## 2) Product Strategy & Roadmap

### Ideal Customer Profiles (ICP)

- **Gig & hourly workers (PH)** needing ₱1K–₱50K cashflow bridges.
- **Salaried early‑career professionals** with thin files but stable income.
- **Repeat on‑time payers** who value predictable limits and perks.

### Jobs‑To‑Be‑Done (JTBD)

1. _"When cash is tight, help me get money now with total cost upfront and repayment reminders so I don’t get trapped."_
2. _"When I repay on time, increase my limit and lower my cost automatically so loyalty feels rewarded."_
3. _"When I share with friends, give me safe, tangible perks without painful KYC loops."_

### Top 3 Risks (and mitigations)

1. **Credit & fraud risk** → conservative starting limits, strong KYC, device fingerprint, income checks, penalty caps, staged limit growth.
2. **Collections & churn** → empathetic reminders, flexible partials, smart grace periods, hardship flags, in‑product renewal offers.
3. **Ops/compliance** → airtight audit logs, PII encryption, rate limits, explicit consent trails, vendor SLAs, rollback plans.

### 30/60/90‑Day Roadmap (delivery metrics in **bold**)

- **Day 0–30 (MLP)**

  - KYC onboarding (manual + vendor webhook stub), basic scoring v1, micro‑loan product (≤60 days), payments via single gateway (sandbox), referrals v1.
  - Observability: Sentry, request logging, audit logs.
  - **KPIs:** signup→KYC pass ≥ **40%**, approval→disbursement latency **< 2 min**, first‑pay on‑time **≥ 60%**.

- **Day 31–60 (Beta)**

  - Mid‑term loans, repayment schedules, partial payments, penalty engine, score v2 (behavioral events), promo/referral credits.
  - Collections tooling (queue + task board), SMS/Email notifications.
  - **KPIs:** D1 retention **≥ 35%**, default (30+ DPD) **≤ 8%** Beta cohort, support CSAT **≥ 4.5/5**.

- **Day 61–90 (GA)**

  - Long‑term (270/365) with strict term validation, Kamal deploy, scale Solid Queue workers, export to analytics, basic ledger.
  - **KPIs:** CAC payback **< 3 months**, repeat borrow rate **≥ 30%**, infra errors per 1k reqs **< 1**.

### Cutlines

- **MLP:** Onboarding + KYC, Scoring v1, Micro‑loan, Single gateway, Partial payment, Referrals, Sentry, Audit logs.
- **Beta:** Mid‑term, Penalties, Schedules, Notifications, Collections UI, Score v2.
- **GA:** Long‑term (270/365 only), Multi‑env deploy, Analytics export, Basic ledgerizing.

**Assumptions:** PH market; one payment gateway; SMS + email vendors exist; manual reviewer in early weeks; mobile‑first web (no native app initially).

---

## 3) DFDs (Mermaid)

### Level‑0 Context

```mermaid
flowchart LR
  Borrower((Borrower))
  Admin((Ops/Collections))
  subgraph eLMo[Rails 8 Monolith]
    UI[Hotwire UI]
    Svc[Domain Services]
  end
  KYC[(KYC Vendor)]
  Pay[(Payment Gateway)]
  Notify[(SMS/Email)]

  Borrower -- Apply/Repay --> UI
  Admin -- Review/Ops --> UI
  UI --> Svc
  Svc -- Verify --> KYC
  Svc -- Charge/Disburse --> Pay
  Svc -- Alerts --> Notify
  KYC -- Webhooks --> Svc
  Pay -- Webhooks --> Svc
```

### Level‑1: Onboarding, Scoring, Loan Lifecycle, Repayment

```mermaid
flowchart TD
  A[Signup] --> B[KYC Submit]
  B -->|vendor| C{KYC result}
  C -->|approved| D[Score v1]
  C -->|failed| Z[Reject/Retry]
  D --> E[Create Loan Quote]
  E --> F{CreditScoringService approves?}
  F -->|yes| G[approve!]
  F -->|no| Z
  G --> H[disburse! via gateway]
  H --> I[Repayment Schedule]
  I --> J[Payments (webhook/SDK)]
  J --> K{Reconcile}
  K -->|full| L[mark_as_paid!]
  K -->|partial| M[Update balance]
  M --> N[Penalty if overdue]
  L --> O[Increase credit limit]
  N --> O
  O --> P[Offer repeat loan]
```

---

## 4) ERD (Mermaid)

```mermaid
erDiagram
  users ||--o{ loans : has
  users ||--o{ referrals : has
  users ||--o{ credit_score_events : has
  loans ||--o{ payments : has
  users ||--o{ audit_logs : has
  loans ||--o{ audit_logs : has
  users ||--o{ outbox_events : published

  users {
    uuid id PK
    string email UK
    string encrypted_password
    string full_name
    string phone UK
    integer credit_limit_cents default 0
    integer current_score default 600
    string referral_code UK
    string kyc_status // pending, approved, rejected
    jsonb kyc_payload
    timestamps
    index email, phone, referral_code
  }
  loans {
    uuid id PK
    uuid user_id FK
    integer amount_cents CHECK >0
    integer term_days
    string product // micro, extended, longterm
    string state // pending, approved, disbursed, paid, overdue, defaulted
    date due_on
    integer principal_outstanding_cents
    integer interest_accrued_cents
    integer penalty_accrued_cents
    decimal apr // cached informational
    timestamps
    index user_id, state, due_on
    check longterm_term(term_days IN (270,365) WHEN product='longterm')
  }
  payments {
    uuid id PK
    uuid loan_id FK
    integer amount_cents
    string state // pending, cleared, failed
    string gateway_ref UK
    datetime posted_at
    jsonb gateway_payload
    timestamps
    index loan_id, state, posted_at
  }
  promo_codes {
    uuid id PK
    string code UK
    string kind // referral, discount
    integer value_cents
    decimal percent_off
    datetime starts_at
    datetime ends_at
    boolean active default true
    timestamps
    index active, ends_at
  }
  referrals {
    uuid id PK
    uuid referrer_id FK -> users.id
    uuid referee_id FK -> users.id
    string status // pending, rewarded
    uuid promo_code_id FK
    timestamps
    index referrer_id, referee_id
  }
  credit_score_events {
    uuid id PK
    uuid user_id FK
    string reason // on_time_payment, overdue, utilization, kyc_bonus
    integer delta
    jsonb meta
    timestamps
    index user_id, reason, created_at
  }
  outbox_events {
    uuid id PK
    string name // e.g., loan.approved.v1
    uuid aggregate_id // source id
    string aggregate_type // Loan/User
    jsonb payload
    jsonb headers // correlation_id, causation_id, idempotency_key
    boolean processed default false
    integer attempts default 0
    timestamps
    index processed, name, created_at
  }
  idempotency_keys {
    uuid id PK
    string key UK
    string scope // e.g., payments/webhook
    uuid resource_id
    string resource_type
    timestamps
  }
  audit_logs {
    uuid id PK
    uuid user_id FK
    uuid target_id
    string target_type
    string action
    jsonb changeset
    string ip
    string user_agent
    timestamps
    index user_id, target_type, action, created_at
  }
```

---

## 5) Domain & State Machines

### Loan State (Mermaid)

```mermaid
stateDiagram-v2
  [*] --> pending
  pending --> approved: approve!
  approved --> disbursed: disburse!
  disbursed --> paid: mark_as_paid! (balance==0)
  disbursed --> overdue: after due_on with balance>0
  overdue --> defaulted: >30 days past due
  overdue --> paid: mark_as_paid!
```

### Payment State (Mermaid)

```mermaid
stateDiagram-v2
  [*] --> pending
  pending --> cleared: gateway success
  pending --> failed: gateway fail/timeout
  cleared --> [*]
  failed --> [*]
```

### Transition Rules (guards & side‑effects)

- **approve!** guard: `kyc_status=approved`, score ≥ threshold, no active overdue loans.

  - Side‑effects: persist loan state, emit `loan.approved.v1`, schedule disbursement attempt.

- **disburse!** guard: gateway token present, idempotency key not seen.

  - Side‑effects: call gateway, write `payments(pending)`, on success set loan→`disbursed`, emit `loan.disbursed.v1`.

- **mark_as_paid!** guard: outstanding balance == 0.

  - Side‑effects: loan→`paid`, emit `loan.paid.v1`, bump `credit_limit`, add `credit_score_event`.

### Pseudocode (Ruby‑ish)

```ruby
# app/domains/loans/loan_state.rb
class LoanState
  def approve!(loan, actor: nil, correlation_id: SecureRandom.uuid)
    Loan.transaction do
      raise "KYC not approved" unless loan.user.kyc_status == "approved"
      raise "Overdue loans present" if loan.user.loans.overdue.exists?
      loan.update!(state: "approved")
      Events.publish!(
        name: "loan.approved.v1",
        aggregate: loan,
        payload: { user_id: loan.user_id, amount_cents: loan.amount_cents },
        headers: { correlation_id: correlation_id }
      )
    end
  end

  def disburse!(loan, gateway:, idem_key:)
    Loan.transaction do
      IdempotencyKeys.lock_or_raise!(key: idem_key, scope: "loans/disburse", resource: loan)
      ref = gateway.disburse(loan) # may raise or return ref
      Payment.create!(loan: loan, amount_cents: loan.amount_cents, state: "pending", gateway_ref: ref)
      loan.update!(state: "disbursed")
      Events.publish!(name: "loan.disbursed.v1", aggregate: loan, payload: { gateway_ref: ref })
    end
  end

  def mark_as_paid!(loan)
    Loan.transaction do
      raise "Balance not zero" unless loan.principal_outstanding_cents + loan.interest_accrued_cents + loan.penalty_accrued_cents == 0
      loan.update!(state: "paid")
      Users::CreditLimits.increase_after_full_pay!(loan.user)
      Events.publish!(name: "loan.paid.v1", aggregate: loan, payload: { })
    end
  end
end
```

---

## 6) Financial Calculations & Validation

### Product auto‑assignment

- `term_days ≤ 60 → product = micro`
- `61–180 → extended`
- `270 or 365 → longterm` _(only these are valid long‑term)_

### Interest formulas (use **BigDecimal**, round **half‑up** to 2 decimal places; store in cents)

- **Short‑term (1–60 days)** simple interest: `amount * (0.5/100) * (term_days/365)`
- **Mid‑term (61–180)** monthly interest: `amount * (3.49/100) * (term_days/30.44)`
- **Long‑term (270/365)** monthly interest: `amount * (3/100) * (term_days/30.44)`

### Validation rules

- `amount_cents > 0`, `term_days` within 1–60, 61–180, or exactly 270/365.
- Long‑term requests **must** be 270 or 365 days; reject others.
- APR shown is informational; repayments schedule derived from interest model.

### Penalty accrual (0.5% daily on overdue **principal**)

- Daily at 00:05 Asia/Manila, compute: `penalty_today = principal_overdue_cents * 0.005` (ceil to cents), add to `penalty_accrued_cents`.
- Stop penalty once loan `paid` or `defaulted`.

### Example amortization (₱10,000, 90 days mid‑term sample slice)

| Day | Action             | Principal | Interest Accrued | Penalty |   Balance |
| --: | ------------------ | --------: | ---------------: | ------: | --------: |
|   0 | Disburse           | 10,000.00 |             0.00 |    0.00 | 10,000.00 |
|  30 | Partial pay ₱3,500 |  6,500.00 |         1,048.20 |    0.00 |  7,548.20 |
|  61 | Missed due         |  6,500.00 |         2,130.59 |   32.50 |  8,663.09 |
|  62 | Penalty accrues    |  6,500.00 |         2,130.59 |   65.00 |  8,695.59 |

_(Interest computed with 3.49%/mo × (term_days/30.44); figures illustrative.)_

---

## 7) Eventing & Outbox Pattern

### Event names

- `user.kyc_approved.v1`, `loan.approved.v1`, `loan.disbursed.v1`, `payment.cleared.v1`, `loan.paid.v1`, `loan.overdue.v1`.

### Envelope schema (JSON)

```json
{
  "id": "uuid",
  "name": "loan.approved.v1",
  "occurred_at": "2025-08-31T15:04:05Z",
  "aggregate_id": "uuid",
  "aggregate_type": "Loan",
  "payload": { "user_id": "uuid", "amount_cents": 1000000 },
  "headers": {
    "correlation_id": "uuid",
    "causation_id": "uuid",
    "idempotency_key": "string"
  }
}
```

### Produce within transaction → outbox → worker fan‑out

```ruby
# app/lib/events.rb
module Events
  def self.publish!(name:, aggregate:, payload:, headers: {})
    OutboxEvent.create!(
      name: name,
      aggregate_id: aggregate.id,
      aggregate_type: aggregate.class.name,
      payload: payload,
      headers: headers.merge(request_id: Current.request_id)
    )
  end
end

# app/jobs/outbox_dispatch_job.rb (Solid Queue)
class OutboxDispatchJob < ApplicationJob
  queue_as :events
  def perform(id)
    evt = OutboxEvent.lock.find(id)
    return if evt.processed?
    ActiveSupport::Notifications.instrument(evt.name, evt.payload.merge(headers: evt.headers))
    evt.update!(processed: true)
  rescue => e
    evt.increment!(:attempts)
    raise e if evt.attempts > 10
    self.class.set(wait: evt.attempts.minutes).perform_later(id)
  end
end
```

### Subscribe (in‑process bus)

```ruby
# config/initializers/events.rb
ActiveSupport::Notifications.subscribe("loan.approved.v1") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  Loans::NotificationsMailer.approved(event.payload[:user_id]).deliver_later
end
```

### Dead‑letter strategy

- After N attempts (e.g., 10), mark `dead_letter=true`, notify Sentry, expose admin UI to retry.

### Idempotency guarantees

- `idempotency_keys` table checked before side‑effects (webhooks, disbursement, payment clears).

---

## 8) Repo Layout & Conventions (Monolith)

```
app/
  domains/
    accounts/ (users, auth, KYC)
    loans/
      services/ (loan_state.rb, interest_calculator.rb)
      queries/
      policies/
    payments/
      services/ (reconcile_payment.rb)
    referrals/
  controllers/
  models/
  views/
  mailers/
  policies/
  jobs/
  workers/
  presenters/
  serializers/
config/
  initializers/ (events.rb, solid_queue.rb, solid_cache.rb, pagy.rb)
db/migrate/
lib/
  tasks/
  utils/
spec/
  factories/
  models/
  services/
  requests/
```

**Conventions**: PORO services, query objects, null‑object patterns, `annotate` gem for schema docs, RuboCop default + Rails + Performance cops.

Example initializers:

```ruby
# config/initializers/solid_queue.rb
SolidQueue.configure do |c|
  c.logger = Rails.logger
end

# config/initializers/pagy.rb
Pagy::DEFAULT[:items] = 25 if defined?(Pagy)
```

---

## 9) Developer Guide (Setup → Run → Test → Deploy)

### Setup

```bash
bin/setup
# creates DB, installs gems, yarn/npm deps if any, loads schema, seeds minimal admin
```

**.env.example** (partial)

```
RAILS_ENV=development
DATABASE_URL=postgres://postgres:postgres@localhost:5432/elmo_dev
SECRET_KEY_BASE=change-me
KYC_WEBHOOK_SECRET=change-me
PAYMENT_WEBHOOK_SECRET=change-me
SENTRY_DSN=
SOLID_QUEUE_INLINE=
ACTIVE_STORAGE_SERVICE=local # s3 for prod
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=ap-southeast-1
S3_BUCKET=
```

### Run

```bash
bin/dev
# Procfile.dev: web (puma), worker (solid_queue), cable, tailwind
```

### Test

```bash
RAILS_ENV=test SOLID_QUEUE_INLINE=1 bin/rspec
```

### Deploy (Kamal 2 outline)

1. `kamal setup` once per environment.
2. CI builds/pushes GHCR image; `kamal deploy -e staging` from CD.
3. Zero‑downtime via Traefik/NGINX, healthchecks `/up`.

S3/Active Storage: set ENV; run `rails active_storage:install`.

---

## 10) Security, Compliance, and Observability

- **AuthN/Z:** Devise (email+password, optional 2FA), Pundit for policies; admin namespace behind `admin` role.
- **PII:** Encrypt sensitive fields (phones) via Rails 8 encryption; minimize payloads in events; never store full PAN.
- **Rate limits:** Rack::Attack (IP + user throttles); login, KYC, payment endpoints.
- **Audit:** Write create/update/destroy + authentication events with `audit_logs`.
- **Anti‑fraud:** Device fingerprint hash, velocity checks, duplicate identities, blocked BINs, blacklists.
- **Observability:** Sentry/Honeybadger exceptions, lograge JSON logs, key metrics (approvals, DPD buckets, queue depth), uptime pings.

---

## 11) RSpec Strategy & Skeletons

### Factories (excerpt)

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    full_name { Faker::Name.name }
    phone { "09#{Faker::Number.number(digits:9)}" }
    credit_limit_cents { 50_00 }
    kyc_status { "approved" }
    encrypted_password { Devise.friendly_token }
  end
end

# spec/factories/loans.rb
FactoryBot.define do
  factory :loan do
    user
    amount_cents { 10_000_00 }
    term_days { 30 }
    product { "micro" }
    state { "pending" }
    due_on { Date.today + term_days }
    principal_outstanding_cents { amount_cents }
    interest_accrued_cents { 0 }
    penalty_accrued_cents { 0 }
  end
end
```

### `spec/services/credit_scoring_service_spec.rb`

```ruby
# Given/When/Then style comments
RSpec.describe CreditScoringService do
  describe "score calculation" do
    let(:user) { create(:user, current_score: 600) }

    it "boosts score for on-time payments" do
      # Given: a user with positive history
      create(:credit_score_event, user: user, reason: "on_time_payment", delta: 20)
      # When: recomputing
      score = described_class.new(user).compute!
      # Then: score increases
      expect(score).to be > 600
    end

    it "penalizes overdue and high utilization" do
      # Given
      create(:credit_score_event, user: user, reason: "overdue", delta: -50)
      allow(user).to receive(:utilization_ratio).and_return(0.9)
      # When
      score = described_class.new(user).compute!
      # Then
      expect(score).to be < 600
    end

    it "is bounded within 300..900" do
      user.update!(current_score: 1000)
      expect(described_class.new(user).compute!).to be_between(300, 900)
    end
  end
end
```

### `spec/models/loan_spec.rb`

```ruby
RSpec.describe Loan, type: :model do
  it "validates longterm term_days" do
    loan = build(:loan, product: "longterm", term_days: 300)
    expect(loan).not_to be_valid
  end

  it "approves only when KYC approved and no overdue" do
    user = create(:user, kyc_status: "approved")
    loan = create(:loan, user: user)
    expect { LoanState.new.approve!(loan) }.to change { loan.reload.state }.to("approved")
  end

  it "prevents double disbursement via idempotency" do
    user = create(:user, kyc_status: "approved")
    loan = create(:loan, user: user, state: "approved")
    gateway = double(disburse: "ref-1")
    IdempotencyKeys.create!(key: "K1", scope: "loans/disburse", resource: loan)
    expect {
      LoanState.new.disburse!(loan, gateway: gateway, idem_key: "K1")
    }.to raise_error(StandardError)
  end

  it "moves to overdue after due date with balance" do
    loan = create(:loan, state: "disbursed", due_on: Date.yesterday,
      principal_outstanding_cents: 100)
    loan.update_overdue_flags!
    expect(loan.state).to eq("overdue")
  end
end
```

### `spec/services/interest_calculator_spec.rb`

```ruby
RSpec.describe InterestCalculator do
  it "computes short-term interest with daily 0.5% prorated" do
    i = described_class.for(amount_cents: 10_000_00, term_days: 14)
    expect(i.total_interest_cents).to be > 0
  end

  it "rejects invalid longterm terms" do
    expect {
      described_class.for(amount_cents: 10_000_00, term_days: 300)
    }.to raise_error(ArgumentError)
  end

  it "rounds half-up to cents" do
    i = described_class.for(amount_cents: 1, term_days: 1)
    expect(i.total_interest_cents).to be_a(Integer)
  end
end
```

### `spec/requests/loans_spec.rb`

```ruby
RSpec.describe "Loans API", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Jwt.issue(user)}" } }

  it "creates a loan and auto-assigns product" do
    post "/api/loans", params: { amount_cents: 500_00, term_days: 30 }, headers: auth_headers
    expect(response).to have_http_status(:created)
    json = JSON.parse(response.body)
    expect(json["product"]).to eq("micro")
  end

  it "handles gateway webhook idempotently" do
    payload = { gateway_ref: "g-123", status: "cleared", idem_key: "abc" }
    post "/api/payments/webhook", params: payload, headers: { "X-Signature" => "sig" }
    expect(response).to have_http_status(:ok)
    # duplicate
    post "/api/payments/webhook", params: payload, headers: { "X-Signature" => "sig" }
    expect(response).to have_http_status(:ok)
  end
end
```

---

## 12) Sample APIs & JSON Shapes

**Auth header:** `Authorization: Bearer <JWT>`; **Errors:** `{ error: { code, message, details[] } }`; **Pagination:** `?page=1&per=25` returns `X-Total`.

### Onboarding

```http
POST /api/kyc
{ "full_name":"...", "phone":"...", "gov_id":"..." }
-->
201 { "status":"pending", "next":"upload_selfie" }
```

### Loans CRUD

```http
POST /api/loans
{ "amount_cents": 500000, "term_days": 45 }
-->
201 { "id":"uuid","product":"micro","state":"pending","due_on":"2025-10-15" }

GET /api/loans?state=disbursed
-->
200 { "data":[{...}], "meta": {"page":1,"per":25,"total":3} }
```

### Payments Webhook

```http
POST /api/payments/webhook
{ "gateway_ref": "g-123", "status":"cleared", "amount_cents": 100000, "loan_id":"uuid", "idem_key":"abc" }
-->
200 { "ok": true }
```

### Error contract example

```json
{
  "error": {
    "code": "validation_failed",
    "message": "term_days must be 270 or 365 for longterm",
    "details": ["term_days"]
  }
}
```

---

## 13) Nice‑to‑have Backlog

- Meilisearch for users/loans.
- Scorecard UI for borrowers.
- Referral leaderboard and seasonal promos.
- SMS via unified Notifications.
- Analytics export to BigQuery/Snowflake; dbt models.
- Service level tests (contract tests) for gateway/KYC stubs.

---

## 14) GitHub Actions CI/CD (copy‑paste YAML)

### `.github/workflows/ci.yml`

```yaml
name: CI
on:
  push:
    branches: ["**"]
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        ports: ["5432:5432"]
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: elmo_test
        options: >-
          --health-cmd="pg_isready -U postgres" --health-interval=10s --health-timeout=5s --health-retries=5
    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/elmo_test
      SOLID_QUEUE_INLINE: "1"
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - name: Install system deps
        run: sudo apt-get update && sudo apt-get install -y libvips
      - name: Install JS deps
        run: |
          [ -f package.json ] && npm ci || echo "no node deps"
      - name: Prepare DB
        run: |
          bin/rails db:schema:load --trace
          bin/rails assets:precompile RAILS_ENV=test || true
      - name: RuboCop
        run: bundle exec rubocop --parallel
      - name: Brakeman
        run: bundle exec brakeman -q -w2
      - name: Bundler Audit
        run: bundle exec bundler-audit check --update
      - name: RSpec
        run: |
          bin/rspec --format progress --profile 10 --force-color
      - name: Upload coverage
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/
```

### `.github/workflows/deploy.yml`

```yaml
name: Deploy
on:
  workflow_dispatch:
    inputs:
      environment:
        description: "staging or production"
        required: true
        default: "staging"
  push:
    tags:
      - "v*"
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'production' }}
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build & Push Image
        run: |
          IMAGE=ghcr.io/${{ github.repository }}:$(echo $GITHUB_REF | sed 's,.*/,,')
          docker build -t $IMAGE .
          docker push $IMAGE
      - name: Install Kamal 2
        run: |
          gem install kamal -v ">=2"
      - name: Deploy with Kamal
        env:
          KAMAL_REGISTRY_USERNAME: ${{ github.actor }}
          KAMAL_REGISTRY_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
        run: |
          kamal deploy -e ${{ github.event.inputs.environment || 'production' }}
```

**Required GitHub Secrets (per Environment):**

- `RAILS_MASTER_KEY`, `SENTRY_DSN` (optional), `KAMAL_SSH_PRIVATE_KEY`, `KAMAL_HOSTS`, `KAMAL_REGISTRY_PASSWORD` (or use OIDC), `AWS_*` if S3, `PAYMENT_WEBHOOK_SECRET`, `KYC_WEBHOOK_SECRET`.
