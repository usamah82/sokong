class CreateVerifications < ActiveRecord::Migration[8.1]
  def change
    create_table :verifications, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :enrolment_id, limit: 36, null: false
      t.json :who_is_here
      t.json :formation
      t.json :daily_life
      t.json :dynamics
      t.json :house
      t.json :needs
      t.json :boxes

      t.timestamps

      t.index :enrolment_id, unique: true
    end

    add_foreign_key :verifications, :enrolments
  end
end
