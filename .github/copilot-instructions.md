# eLMo (Loan More App) — Copilot Instructions

eLMo is a Rails 8 fintech application for micro-lending built with Solid Queue/Cache/Cable, PostgreSQL, and Hotwire. This is a monolith following domain-driven patterns within Rails conventions.

## Architecture Overview

- **Rails 8 monolith** with Solid Queue for background jobs, Solid Cache for caching, Solid Cable for WebSockets
- **PostgreSQL** with multiple databases (primary, cache, queue, cable) configured for production scaling
- **Hotwire** (Turbo + Stimulus) for reactive frontend without SPA complexity
- **Kamal 2** deployment with Docker containers and zero-downtime deploys
- **Domain services** pattern: keep controllers thin, move business logic to `app/services/`

## Key Files & Patterns

- `bin/dev` - Development server using Foreman with Procfile.dev (web, js, css processes)
- `bin/setup` - Idempotent setup script that installs deps and starts server
- `bun.config.js` - JavaScript bundling with Bun (watch mode for development)
- `config/deploy.yml` - Kamal deployment configuration
- `config/database.yml` - Multi-database setup (primary, cache, queue, cable)

## Development Workflow

```bash
# Setup (idempotent)
bin/setup

# Development (runs web server + asset watchers)
bin/dev

# Testing
bin/rails test
# OR if RSpec is added:
bundle exec rspec

# Linting & Security
bundle exec rubocop --parallel
bundle exec brakeman -q -w2
```

## Code Conventions

- **UUID primary keys** and timestamps on all models
- **Service objects** for business logic: `app/services/namespace/verb_noun.rb`
- **PORO approach** over heavy frameworks - plain Ruby objects with clear interfaces
- **BigDecimal** for financial calculations, store monetary values in cents (integer)
- **Enum with strings** (not integers) for auditability
- **Database constraints** matching model validations

## Financial Domain Specifics

Based on `docs/elmo-plan.md`:

- **Loan products**: micro (≤60 days), extended (61-180), longterm (270/365 only)
- **Interest calculation**: Different formulas per product tier, BigDecimal with half-up rounding
- **State machines**: Loan states (pending → approved → disbursed → paid/overdue/defaulted)
- **Outbox pattern**: Events stored in `outbox_events` table, processed by background jobs
- **Idempotency**: Use `idempotency_keys` table for webhooks and critical operations

## Testing Strategy

Uses Rails' built-in testing framework (see `test/test_helper.rb`):

- **Parallel test execution** enabled
- **System tests** with Capybara/Selenium for integration
- **Fixtures** for test data (all fixtures loaded)

If migrating to RSpec, follow patterns from `docs/elmo-plan.md` section 11.

## Asset Pipeline

- **Bun** for JavaScript bundling (`bun.config.js`)
- **Tailwind CSS** via cssbundling-rails
- **Propshaft** for asset delivery (Rails 8 default)
- Assets built to `app/assets/builds/`

## Deployment

- **Kamal 2** with Docker containers
- **Solid Queue in Puma** process for jobs (configurable)
- **Let's Encrypt SSL** auto-certification
- **Volume persistence** for storage and uploads

## Security Principles

- **Credentials** via Rails encrypted credentials or ENV vars
- **Strong parameters** for all controller inputs
- **PII filtering** in logs (configure filtered_parameters)
- **Rate limiting** with Rack::Attack (add to Gemfile if needed)
- **Audit logging** for sensitive operations

## AI Assistant Guidelines

1. **Never suggest console/server commands** - use appropriate tools
2. **Reference exact file paths** when suggesting changes
3. **Generate complete, paste-ready code blocks**
4. **Follow Rails 8 conventions** - no Rails Engines or over-engineering
5. **Include tests** for any new functionality
6. **Use domain language** from `docs/elmo-plan.md` for financial features
7. **Consider multi-database setup** when suggesting migrations
8. **Default to secure, production-ready patterns**
9. **Always test locally before pushing** - run `bin/rails test` to verify all tests pass before committing and pushing changes

## Domain-Specific Patterns

When working on financial features:

- **Always validate loan term constraints** (270/365 for longterm)
- **Use state machines** for loan lifecycle management
- **Emit events** for audit trails and downstream processing
- **Handle money with precision** - BigDecimal, cents storage
- **Consider idempotency** for payment operations
- **Implement proper authorization** - users can only access their own data

For questions about business logic, reference `docs/elmo-plan.md` which contains the complete product specification, ERD, state diagrams, and financial calculation rules.
