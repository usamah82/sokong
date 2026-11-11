class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :email, null: false
      t.string :email_normalized, null: false
      t.string :role, null: false
      t.string :password_digest, null: false
      t.datetime :email_confirmed_at

      t.timestamps

      t.index :email_normalized, unique: true
    end

    add_foreign_key :locality_assignments, :accounts
  end
end
