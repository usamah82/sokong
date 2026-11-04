class CreateEnrolments < ActiveRecord::Migration[8.1]
  def change
    create_table :family_units, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true

      t.timestamps
    end

    create_table :family_members, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :family_unit_id, limit: 36, null: false
      t.string :role, null: false
      t.integer :position, null: false
      t.string :name, null: false
      t.integer :age
      t.string :gender, null: false
      t.string :description, null: false
      t.boolean :in_education, null: false
      t.boolean :working, null: false
      t.string :job, null: false
      t.integer :monthly_amount

      t.timestamps

      t.index :family_unit_id
    end

    create_table :enrolments, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :family_unit_id, limit: 36, null: false
      t.string :locality_id, limit: 36, null: false
      t.datetime :submitted_at, null: false
      t.boolean :on_behalf, null: false
      t.string :consent_text, null: false
      t.string :enroler_contact, null: false
      t.string :email, null: false
      t.string :place_name, null: false
      t.decimal :latitude
      t.decimal :longitude
      t.string :family_phone, null: false
      t.string :how_to_find, null: false
      t.json :help, null: false
      t.string :other_help, null: false
      t.datetime :visit_at

      t.timestamps

      t.index :family_unit_id, unique: true
      t.index :locality_id
    end

    add_foreign_key :family_members, :family_units
    add_foreign_key :enrolments, :family_units
    add_foreign_key :enrolments, :localities
  end
end
