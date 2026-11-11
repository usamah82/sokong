class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :email, null: false
      t.string :email_normalized, null: false
      t.string :name, null: false, default: ""
      t.string :role, null: false
      t.string :password_digest, null: false

      t.timestamps

      t.index :email_normalized, unique: true
    end

    create_table :auth_tokens, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :account_id, limit: 36, null: false
      t.string :token_digest, null: false

      t.timestamps

      t.index :token_digest, unique: true
    end

    add_foreign_key :auth_tokens, :accounts
    add_foreign_key :locality_assignments, :accounts
  end
end
