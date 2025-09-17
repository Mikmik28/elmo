class AddRejectedStateToLoans < ActiveRecord::Migration[8.0]
  def change
    # Remove the old constraint
    remove_check_constraint :loans, name: "loans_valid_state"
    
    # Add the new constraint with rejected state
    add_check_constraint :loans, "state IN ('pending', 'approved', 'rejected', 'disbursed', 'paid', 'overdue', 'defaulted')", name: "loans_valid_state"
  end
end
