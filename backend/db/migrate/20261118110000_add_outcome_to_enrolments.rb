class AddOutcomeToEnrolments < ActiveRecord::Migration[8.1]
  def change
    add_column :enrolments, :outcome, :string
    add_column :enrolments, :marked_at, :datetime
    add_column :enrolments, :marker_name, :string
  end
end
