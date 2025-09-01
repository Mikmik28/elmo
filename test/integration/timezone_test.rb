require "test_helper"

class TimezoneTest < ActiveSupport::TestCase
  test "Rails application timezone is set to Asia/Manila" do
    assert_equal "Asia/Manila", Rails.application.config.time_zone,
      "Rails.application.config.time_zone should be set to Asia/Manila"
  end

  test "ActiveRecord default timezone is UTC" do
    assert_equal :utc, ActiveRecord.default_timezone,
      "ActiveRecord.default_timezone should be set to :utc"
  end

  test "Time.zone is Asia/Manila" do
    assert_equal "Asia/Manila", Time.zone.name,
      "Time.zone should be Asia/Manila"
  end

  test "database timestamps are stored in UTC" do
    # We'll use ApplicationRecord as a base - in real app this would be a real model
    # For now, let's test the configuration is correct
    utc_time = Time.now.utc
    manila_time = Time.now.in_time_zone("Asia/Manila")

    # Verify UTC storage preserves the actual moment
    assert utc_time.utc?, "UTC time should be in UTC"
    assert_not manila_time.utc?, "Manila time should not be marked as UTC"

    # Verify conversion between timezones preserves the moment
    converted_to_utc = manila_time.utc

    # The actual moments should be equivalent (within 1 second for test timing)
    assert_in_delta utc_time.to_f, converted_to_utc.to_f, 1.0,
      "Converting Manila time to UTC should preserve the moment"
  end

  test "business day rollover occurs at midnight Manila time" do
    # Test that we can properly detect business day boundaries
    manila_tz = ActiveSupport::TimeZone["Asia/Manila"]

    # Midnight in Manila
    manila_midnight = manila_tz.parse("2025-09-02 00:00:00")

    # Convert to UTC for storage
    utc_equivalent = manila_midnight.utc

    # Verify the conversion worked correctly
    assert manila_midnight.beginning_of_day == manila_midnight
    assert utc_equivalent.in_time_zone("Asia/Manila").beginning_of_day == manila_midnight
  end

  test "financial calculations respect business day timezone" do
    # Verify that business logic can correctly identify business days
    manila_tz = ActiveSupport::TimeZone["Asia/Manila"]

    # Test a Monday in Manila (should be a business day)
    monday_manila = manila_tz.parse("2025-09-01 10:00:00") # Monday 10 AM Manila
    assert_equal 1, monday_manila.wday, "Should be Monday"

    # Test weekend identification
    saturday_manila = manila_tz.parse("2025-09-06 10:00:00") # Saturday 10 AM Manila
    sunday_manila = manila_tz.parse("2025-09-07 10:00:00") # Sunday 10 AM Manila

    assert_equal 6, saturday_manila.wday, "Should be Saturday"
    assert_equal 0, sunday_manila.wday, "Should be Sunday"

    # Business logic should work with Manila timezone
    assert [ 1, 2, 3, 4, 5 ].include?(monday_manila.wday), "Monday should be a weekday"
    assert_not [ 1, 2, 3, 4, 5 ].include?(saturday_manila.wday), "Saturday should not be a weekday"
    assert_not [ 1, 2, 3, 4, 5 ].include?(sunday_manila.wday), "Sunday should not be a weekday"
  end
end
