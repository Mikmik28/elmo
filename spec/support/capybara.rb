# Capybara configuration for system tests

require 'capybara/rails'
require 'selenium-webdriver'

# Configure Capybara to use Selenium with Chrome
Capybara.register_driver :selenium_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# For debugging with visible browser
Capybara.register_driver :selenium_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Configure default settings
Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  # Use headless Chrome for system tests by default
  config.before(:each, type: :system) do
    driven_by :selenium_headless_chrome
  end

  # For debugging, use visible browser (run with DEBUG=true)
  config.before(:each, type: :system, debug: true) do
    driven_by :selenium_chrome
  end

  # For tests that specifically need JavaScript
  config.before(:each, type: :system, js: true) do
    driven_by :selenium_headless_chrome
  end
end
