class AddPreVisitToEnrolments < ActiveRecord::Migration[8.1]
  def change
    add_column :enrolments, :bringing_basket, :boolean
    add_column :enrolments, :assigned_workers, :json
  end
end
