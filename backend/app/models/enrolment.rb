class Enrolment < ApplicationRecord
  belongs_to :family_unit
  belongs_to :locality
  has_many :members, -> { order(:position) }, through: :family_unit
  has_many :looks, -> { order(:looked_at, :created_at) }, dependent: :destroy

  VISIT_AT_FORMAT = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})\z/

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

  def schedule_visit(visit_at:, bringing_basket:, assigned_workers:)
    instant = parsed_visit_at(visit_at)
    return instant if instant.is_a?(Symbol)

    basket = parsed_basket(bringing_basket)
    return basket if basket.is_a?(Symbol)

    names = parsed_workers(assigned_workers)
    return names if names.is_a?(Symbol)

    return self if same_pre_visit?(instant, basket, names)

    update!(visit_at: instant, bringing_basket: basket, assigned_workers: names)
    self
  end

  def pre_visit_json
    {
      visit_at: visit_at&.utc&.iso8601,
      bringing_basket: bringing_basket,
      assigned_workers: assigned_workers
    }
  end

  private
    def parsed_visit_at(value)
      match = VISIT_AT_FORMAT.match(value.to_s)
      return :visit_invalid unless match
      return :visit_invalid unless Date.valid_date?(match[1].to_i, match[2].to_i, match[3].to_i)
      return :visit_invalid unless match[4].to_i <= 23 && match[5].to_i <= 59 && match[6].to_i <= 59

      Time.iso8601(value).utc.change(usec: 0)
    rescue ArgumentError
      :visit_invalid
    end

    def parsed_basket(value)
      return value if value == true || value == false

      :basket_invalid
    end

    def parsed_workers(value)
      return :worker_required if value.nil?
      return :worker_invalid unless value.is_a?(Array)
      return :worker_required if value.empty?
      return :worker_invalid if value.size > 10

      value.map do |name|
        cleaned = cleaned_worker(name)
        return cleaned if cleaned.is_a?(Symbol)

        cleaned
      end
    end

    def cleaned_worker(name)
      return :worker_invalid unless name.is_a?(String)

      cleaned = name.strip
      return :worker_required if cleaned.empty?
      return :worker_invalid if cleaned.length > 200

      cleaned
    end

    def same_pre_visit?(instant, basket, names)
      visit_at&.change(usec: 0) == instant && bringing_basket == basket && assigned_workers == names
    end
end
