class CreateLooks < ActiveRecord::Migration[8.1]
  def change
    create_table :looks, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :enrolment_id, limit: 36, null: false
      t.string :account_id, limit: 36, null: false
      t.string :worker_name, null: false
      t.datetime :looked_at, null: false
      t.string :note, null: false, default: ""

      t.timestamps

      t.index :enrolment_id
      t.index :account_id
    end

    add_foreign_key :looks, :enrolments
    add_foreign_key :looks, :accounts
  end
end
