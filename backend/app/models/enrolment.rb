class Enrolment < ApplicationRecord
  belongs_to :family_unit
  belongs_to :locality
  has_many :members, -> { order(:position) }, through: :family_unit
  has_many :looks, -> { order(:looked_at, :created_at) }, dependent: :destroy

  def self.record!(**attributes)
    transaction do
      locality = Locality.claim(place_name: attributes[:place_name], point: point_from(attributes))
      family_unit = FamilyUnit.create!
      ordered_members(attributes[:members]).each_with_index do |member, position|
        family_unit.members.create!(member_attributes(member, position))
      end
      create!(enrolment_attributes(attributes, family_unit, locality))
    end
  end

  class << self
    private
      def point_from(attributes)
        latitude = attributes[:latitude]
        longitude = attributes[:longitude]
        return if latitude.nil? || longitude.nil?

        [ latitude, longitude ]
      end

      def ordered_members(members)
        list = Array(members).map { |member| member.symbolize_keys }
        heads, others = list.partition { |member| member[:role] == "head" }
        heads + others
      end

      def member_attributes(member, position)
        working = member[:working] == true

        {
          role: member[:role],
          position: position,
          name: member[:name],
          age: blank_number(member[:age]),
          gender: member[:gender],
          description: empty_string(member[:description]),
          in_education: member[:in_education] == true,
          working: working,
          job: working ? empty_string(member[:job]) : "",
          monthly_amount: working ? blank_number(member[:monthly_amount]) : nil
        }
      end

      def enrolment_attributes(attributes, family_unit, locality)
        {
          family_unit: family_unit,
          locality: locality,
          submitted_at: Time.current,
          on_behalf: attributes[:on_behalf] == true,
          consent_text: attributes[:consent_text],
          enroler_contact: attributes[:enroler_contact],
          email: empty_string(attributes[:email]),
          place_name: attributes[:place_name],
          latitude: attributes[:latitude],
          longitude: attributes[:longitude],
          family_phone: empty_string(attributes[:family_phone]),
          how_to_find: empty_string(attributes[:how_to_find]),
          help: Array(attributes[:help]).uniq,
          other_help: empty_string(attributes[:other_help])
        }
      end

      def empty_string(value)
        return "" if value.nil? || value.to_s.strip.empty?

        value
      end

      def blank_number(value)
        return nil if value.nil?
        return nil if value.is_a?(String) && value.strip.empty?

        value
      end
  end
end
