class FamilyUnit < ApplicationRecord
  has_many :members, -> { order(:position) }, class_name: "FamilyMember"
end
