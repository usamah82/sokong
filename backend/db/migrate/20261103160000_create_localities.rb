class CreateLocalities < ActiveRecord::Migration[8.1]
  def change
    create_table :localities, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :name, null: false
      t.decimal :latitude
      t.decimal :longitude
      t.integer :radius_metres

      t.timestamps
    end

    create_table :locality_assignments, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :account_id, limit: 36, null: false
      t.string :locality_id, limit: 36, null: false

      t.timestamps

      t.index :locality_id
    end

    add_foreign_key :locality_assignments, :localities
  end
end
