# eLMo (Loan More App)

A Rails 8 fintech application for micro-lending built with modern Ruby tooling and financial-grade reliability.

## Quick Start

```bash
# Setup (idempotent)
bin/setup

# Development (runs web server + asset watchers)
bin/dev

# Testing
bin/rails test

# Linting & Security
bundle exec rubocop --parallel
bundle exec brakeman -q -w2
```

## Project Overview

eLMo is a monolithic Rails 8 application designed for micro-lending operations with:

- **Modern Stack**: Rails 8, PostgreSQL 16+, Solid Queue/Cache/Cable
- **Frontend**: Hotwire (Turbo + Stimulus) + Tailwind CSS
- **Deployment**: Kamal 2 with Docker containers
- **Architecture**: Domain-driven patterns within Rails conventions

## Documentation

- **[Project Assumptions & Conventions](docs/assumptions.md)** - Core guidelines and technical decisions
- **[eLMo Plan](docs/elmo-plan.md)** - Complete product specification and business rules
- **[Copilot Instructions](.github/copilot-instructions.md)** - AI assistant guidelines

## Requirements

- **Ruby**: 3.3+ (see `.ruby-version`)
- **Rails**: 8.x
- **PostgreSQL**: 16+
- **Node.js**: For asset compilation (Bun)
- **Docker**: For deployment

## Architecture

This is a Rails 8 monolith with:

- **Multi-database setup**: primary, cache, queue, cable databases
- **Service objects**: Business logic in `app/services/`
- **Outbox pattern**: Event-driven architecture for reliability
- **UUID primary keys**: Better for distributed systems
- **Financial precision**: BigDecimal for monetary calculations

## Development

### Environment Setup

The `bin/setup` script handles all development dependencies:

```bash
bin/setup  # Installs gems, creates databases, runs migrations
```

### Development Server

Use the integrated development server that runs all necessary processes:

```bash
bin/dev  # Starts Rails server, JS bundler, CSS compiler
```

This uses Foreman with `Procfile.dev` to run:
- Rails server on port 3000
- Bun for JavaScript bundling (watch mode)
- Tailwind CSS compilation (watch mode)

### Testing

```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/user_test.rb

# Run with coverage
COVERAGE=true bin/rails test
```

### Code Quality

```bash
# Ruby linting
bundle exec rubocop --parallel

# Security analysis
bundle exec brakeman -q -w2

# Dependency vulnerability check
bundle audit
```

## Database

Multi-database configuration for production scaling:

```yaml
# config/database.yml
production:
  primary: # Main application data
  cache:   # Solid Cache
  queue:   # Solid Queue
  cable:   # Solid Cable
```

### Migrations

```bash
# Create migration
bin/rails generate migration CreateUsers

# Run migrations
bin/rails db:migrate

# For specific database
bin/rails db:migrate:cache
```

## Deployment

Deployed using Kamal 2 with zero-downtime deployments:

```bash
# Deploy to production
kamal deploy

# Deploy to staging
kamal deploy -d staging

# Check deployment status
kamal app details
```

See `config/deploy.yml` for deployment configuration.

## Business Domain

eLMo focuses on micro-lending with three product tiers:

- **Micro**: ≤60 days, small amounts
- **Extended**: 61-180 days, moderate amounts  
- **Long-term**: 270/365 days only, larger amounts

Key features:
- KYC verification and credit scoring
- Automated loan processing and disbursement
- Payment tracking and collections
- Comprehensive audit trails

## Security & Compliance

- **PII Protection**: Encrypted sensitive data, filtered logs
- **Financial Accuracy**: BigDecimal calculations, banker's rounding
- **Idempotency**: All mutable operations require idempotency keys
- **Rate Limiting**: Protection against abuse
- **Audit Logging**: Complete trail for compliance

## Contributing

1. Read [Project Assumptions & Conventions](docs/assumptions.md)
2. Follow the development workflow in the assumptions document
3. Ensure all tests pass and code quality checks succeed
4. Submit pull requests with clear descriptions

## Support

For questions about business logic, see the [eLMo Plan](docs/elmo-plan.md) document which contains complete product specifications, ERD, state diagrams, and financial calculation rules.
