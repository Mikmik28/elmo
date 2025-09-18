source "https://rubygems.org"

ruby "3.4.3"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2", ">= 8.0.2.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"
# Hotwire Turbo for reactive frontend [https://github.com/hotwired/turbo-rails]
gem "turbo-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Authentication solution for Rails [https://github.com/plataformatec/devise]
gem "devise"

# Two-Factor Authentication
gem "devise-two-factor"

# For TOTP generation and verification [https://github.com/mdp/rotp]
gem "rotp"

# For QR code generation [https://github.com/whomwah/rqrcode]
gem "rqrcode"

# Object oriented authorization for Rails [https://github.com/elabs/pundit]
gem "pundit"

# Rack middleware for blocking & throttling abusive requests [https://github.com/rack/rack-attack]
gem "rack-attack"

# Search functionality using PostgreSQL full text search [https://github.com/Casecommons/pg_search]
gem "pg_search"

# Model annotation for Rails [https://github.com/drwl/annotaterb]
gem "annotaterb"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Bundler audit for security vulnerabilities in dependencies
  gem "bundler-audit", require: false

  # RSpec testing framework for Rails [https://github.com/rspec/rspec-rails]
  gem "rspec-rails"

  # Factory library for setting up Ruby objects as test data [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails"

  # Database cleaner strategies for cleaning database in tests [https://github.com/DatabaseCleaner/database_cleaner]
  gem "database_cleaner-active_record"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Preview emails in the browser instead of sending them [https://github.com/ryanb/letter_opener]
  gem "letter_opener"

  # Web interface for letter_opener [https://github.com/fgrehm/letter_opener_web]
  gem "letter_opener_web"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Shoulda matchers for cleaner model and controller tests
  gem "shoulda-matchers"

  # A library for generating fake data [https://github.com/faker-ruby/faker]
  gem "faker"
end
