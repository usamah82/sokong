class CreateAuthTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :auth_tokens, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :account_id, limit: 36, null: false
      t.string :token_digest, null: false

      t.timestamps

      t.index :token_digest, unique: true
      t.index :account_id
    end

    add_foreign_key :auth_tokens, :accounts
  end
end
