require "test_helper"

class AssumptionsDocumentTest < ActiveSupport::TestCase
  def setup
    # Skip database tests for this simple document verification
    self.use_transactional_tests = false
  end

  test "assumptions document exists and contains key statements" do
    assumptions_path = Rails.root.join("docs", "assumptions.md")
    
    assert File.exist?(assumptions_path), "docs/assumptions.md should exist"
    
    content = File.read(assumptions_path)
    
    # Verify key assumptions are documented
    assert_includes content, "3.3+", "Should document Ruby version requirement"
    assert_includes content, "Rails 8", "Should document Rails version requirement"
    assert_includes content, "PostgreSQL 16+", "Should document PostgreSQL version requirement"
    assert_includes content, "UTC", "Should document UTC storage for timestamps"
    assert_includes content, "Asia/Manila", "Should document default timezone"
    assert_includes content, "decimal(18,4)", "Should document money storage format"
    assert_includes content, "Banker's rounding", "Should document rounding method"
    assert_includes content, "Idempotency-Key", "Should document idempotency requirement"
    assert_includes content, "outbox_events", "Should document outbox pattern"
    assert_includes content, "UUID", "Should document UUID primary keys"
  end
  
  test "README references assumptions document" do
    readme_path = Rails.root.join("README.md")
    
    assert File.exist?(readme_path), "README.md should exist"
    
    content = File.read(readme_path)
    assert_includes content, "docs/assumptions.md", "README should reference assumptions document"
    assert_includes content, "Project Assumptions & Conventions", "README should mention assumptions"
  end
  
  test "copilot instructions exist" do
    copilot_path = Rails.root.join(".github", "copilot-instructions.md")
    
    assert File.exist?(copilot_path), ".github/copilot-instructions.md should exist"
    
    content = File.read(copilot_path)
    assert_includes content, "eLMo", "Should be eLMo specific instructions"
    assert_includes content, "Rails 8", "Should reference Rails 8"
  end
  
  test "elmo plan document exists" do
    plan_path = Rails.root.join("docs", "elmo-plan.md")
    
    assert File.exist?(plan_path), "docs/elmo-plan.md should exist"
  end
end
