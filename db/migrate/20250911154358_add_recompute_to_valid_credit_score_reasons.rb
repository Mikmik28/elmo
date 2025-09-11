class AddRecomputeToValidCreditScoreReasons < ActiveRecord::Migration[8.0]
  def up
    # Remove the old constraint
    remove_check_constraint :credit_score_events, name: "credit_score_events_valid_reason"

    # Add the new constraint with "recompute" included
    add_check_constraint :credit_score_events, "reason IN ('on_time_payment', 'overdue', 'utilization', 'kyc_bonus', 'default', 'recompute')", name: "credit_score_events_valid_reason"
  end

  def down
    # Remove the new constraint
    remove_check_constraint :credit_score_events, name: "credit_score_events_valid_reason"

    # Add back the old constraint
    add_check_constraint :credit_score_events, "reason IN ('on_time_payment', 'overdue', 'utilization', 'kyc_bonus', 'default')", name: "credit_score_events_valid_reason"
  end
end
