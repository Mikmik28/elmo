# eLMo Project Assumptions & Conventions

This document outlines the core assumptions and conventions for the eLMo (Loan More App) fintech application. All team members should follow these guidelines to ensure consistency across the codebase.

## Technology Stack

- **Ruby**: 3.4.3+ (latest stable version)
- **Rails**: 8 monolith architecture (no engines)
- **Database**: PostgreSQL 16+ with multiple databases (primary, cache, queue, cable)
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Authentication**: Devise
- **Authorization**: Pundit
- **Search**: pg_search
- **Deployment**: Kamal 2
- **CI/CD**: GitHub Actions
- **Event Architecture**: Outbox pattern

## Time & Timezone Management

- **Storage**: All timestamps stored in UTC in the database
- **Display**: Default timezone is Asia/Manila for user-facing interfaces
- **Business Logic**: Business day rollovers occur at 00:00 Asia/Manila
- **Configuration**:
  - `Rails.application.config.time_zone = 'Asia/Manila'`
  - `ActiveRecord.default_timezone = :utc`

## Financial Data Handling

### Money Storage & Precision

- **Data Type**: `integer` for monetary values (stored in cents)
- **Currency**: Primarily Philippine Peso (PHP)
- **Storage**: Monetary values stored in cents (integer)
- **Precision**: Calculations should use 4 decimal places for accuracy (use `BigDecimal` for all financial calculations)

### Rounding & Calculations

- **Rounding Method**: Banker's rounding (round half to even)
- **Interest Calculation**: Per product-specific rules (see loan product documentation)
- **Pro-rating**: Based on actual term_days for accurate daily calculations
- **Implementation**: Use `BigDecimal` for all financial calculations

## API Design & Reliability

### Idempotency

- **Requirement**: All mutable endpoints MUST require an "Idempotency-Key" header
- **Key Format**: UUID v4 recommended
- **Deduplication**: Webhooks deduplicated by provider event ID
- **Storage**: Use `idempotency_keys` table for tracking

### Rate Limiting

- **Login Endpoints**: Rate limited per IP address and email
- **Webhook Ingestion**: Rate limited per provider specification
- **Implementation**: Use Rack::Attack for rate limiting

## Event-Driven Architecture

### Domain Events

- **Pattern**: Outbox pattern implementation
- **Storage**: Events stored in `outbox_events` table
- **Uniqueness**: Each event has a unique key to prevent duplicates
- **Processing**: Asynchronous publisher processes events from outbox
- **Reliability**: At-least-once delivery guarantee

### Event Schema

```ruby
# outbox_events table structure
create_table :outbox_events, id: :uuid do |t|
  t.string :event_type, null: false
  t.string :aggregate_type, null: false
  t.uuid :aggregate_id, null: false
  t.json :payload, null: false
  t.string :unique_key, null: false, index: { unique: true }
  t.datetime :processed_at
  t.timestamps
end
```

## Data Modeling Conventions

### Primary Keys

- **Type**: UUID for all models
- **Implementation**: Use `id: :uuid` in migrations
- **Benefits**: Better for distributed systems and external API exposure

### Model Structure

- **Timestamps**: Include `created_at` and `updated_at` on all models
- **Enums**: Use string-based enums (not integers) for better auditability
- **Constraints**: Database constraints should match model validations
- **Naming**: Follow Rails conventions with domain-specific terminology

### State Machines

- **Loan States**: pending → approved → disbursed → paid/overdue/defaulted
- **Implementation**: Use state machine gems (e.g., AASM or state_machines)
- **Events**: Emit domain events for all state transitions

## Environment Configuration

### Environments

- **Development**: Local development with hot reloading
- **Test**: Automated testing with parallel execution
- **Staging**: Production-like environment for pre-deployment testing
- **Production**: Live environment with full monitoring and logging

### Configuration Management

- **Secrets**: Use Rails encrypted credentials or environment variables
- **Database**: Multi-database configuration in `config/database.yml`
- **Deployment**: Environment-specific settings in `config/deploy.yml`

## Development Workflow

### Code Organization

- **Controllers**: Keep thin, delegate to service objects
- **Services**: Business logic in `app/services/namespace/verb_noun.rb`
- **Models**: Focus on data integrity and relationships
- **Jobs**: Background processing with Solid Queue

### Testing Strategy

- **Framework**: Rails built-in testing framework (Minitest)
- **Parallel**: Enable parallel test execution for faster feedback
- **Coverage**: Focus on business logic and critical paths
- **System Tests**: Use Capybara for integration testing

### Asset Pipeline

- **JavaScript**: Bun for bundling with watch mode in development
- **CSS**: Tailwind CSS via cssbundling-rails
- **Delivery**: Propshaft for asset delivery (Rails 8 default)
- **Build**: Assets built to `app/assets/builds/`

## Security Requirements

### Data Protection

- **PII Filtering**: Configure `filtered_parameters` for sensitive data
- **Encryption**: Use Rails encrypted attributes for sensitive fields
- **Access Control**: Implement proper authorization with Pundit
- **Audit Logging**: Log all sensitive operations with user context

### API Security

- **Authentication**: Token-based authentication for API endpoints
- **Authorization**: Role-based access control
- **Input Validation**: Strong parameters for all controller inputs
- **Rate Limiting**: Protect against abuse and DDoS

## Deployment & Infrastructure

### Containerization

- **Platform**: Docker containers with Kamal 2
- **SSL**: Automatic Let's Encrypt SSL certification
- **Persistence**: Volume persistence for storage and uploads
- **Scaling**: Horizontal scaling support

### Monitoring & Observability

- **Logging**: Structured logging with relevant context
- **Metrics**: Application and business metrics collection
- **Alerts**: Critical error and performance alerts
- **Health Checks**: Endpoint health monitoring

## Code Quality Standards

### Linting & Analysis

- **Ruby**: RuboCop with custom configuration
- **Security**: Brakeman for security analysis
- **Dependencies**: Regular dependency updates and vulnerability scanning

### Documentation

- **Code**: Inline documentation for complex business logic
- **API**: OpenAPI specification for external APIs
- **Architecture**: Decision records for significant changes
- **Setup**: Comprehensive README and setup instructions

## Business Domain Specifics

### Loan Products

- **Micro Loans**: ≤ 60 days term
- **Extended Loans**: 61-180 days term
- **Long-term Loans**: 270 or 365 days only (no other terms allowed)

### Interest Calculation

- **Method**: Product-tier specific formulas
- **Precision**: BigDecimal with half-up rounding
- **Validation**: Strict term validation for long-term products

### Compliance & Audit

- **Regulations**: Follow BSP and SEC guidelines for fintech
- **Audit Trail**: Complete audit trail for all financial transactions
- **Reporting**: Regular compliance and financial reporting
- **Data Retention**: Follow regulatory requirements for data retention

---

## References

- [eLMo Plan Document](./elmo-plan.md) - Detailed product specification
- [Copilot Instructions](../.github/copilot-instructions.md) - AI assistant guidelines
- [Rails 8 Documentation](https://guides.rubyonrails.org/) - Framework reference
- [PostgreSQL Documentation](https://www.postgresql.org/docs/) - Database reference

## Version History

- **v1.0** (2025-09-02): Initial assumptions and conventions document
