class CreateEmailConfirmations < ActiveRecord::Migration[8.1]
  def change
    create_table :email_confirmations, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :account_id, limit: 36, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false

      t.timestamps

      t.index :account_id, unique: true
      t.index :token_digest, unique: true
    end

    add_foreign_key :email_confirmations, :accounts
  end
end
