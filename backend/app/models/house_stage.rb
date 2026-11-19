class HouseStage
  KEYS = %w[
    place rent_per_month behind_on_payments has_water has_electricity sleeping_rooms
    safe unsafe_detail meals basket notes
  ].freeze
  PLACES = %w[own rent staying_with_someone temporary].freeze
  MEALS = %w[three two one not_every_day].freeze
  FIELD_ORDER = KEYS

  def self.clean(input, enrolment:)
    new(input, enrolment).clean
  end

  def initialize(input, _enrolment)
    @input = input
    @errors = []
  end

  def clean
    place = clean_choice(@input["place"], PLACES, "place", "This place")
    payload = {
      "place" => place,
      "rent_per_month" => nil,
      "behind_on_payments" => nil,
      "has_water" => clean_boolean(@input["has_water"], "has_water", "Does it have water?"),
      "has_electricity" => clean_boolean(@input["has_electricity"], "has_electricity", "Does it have electricity?"),
      "sleeping_rooms" => clean_integer(@input["sleeping_rooms"], "sleeping_rooms", "How many rooms do people sleep in?", 99),
      "safe" => clean_boolean(@input["safe"], "safe", "Is this place safe?"),
      "unsafe_detail" => "",
      "meals" => clean_choice(@input["meals"], MEALS, "meals", "How many meals a day?"),
      "basket" => clean_text(@input["basket"], "basket", "Basket", 500),
      "notes" => clean_text(@input["notes"], "notes", "Anything else they said", 2000)
    }
    if place == "rent"
      payload["rent_per_month"] = clean_integer(@input["rent_per_month"], "rent_per_month", "Rent per month", 999_999_999)
      payload["behind_on_payments"] = clean_boolean(@input["behind_on_payments"], "behind_on_payments", "Are you behind on payments?")
    end
    payload["unsafe_detail"] = clean_text(@input["unsafe_detail"], "unsafe_detail", "What feels unsafe?", 2000) if payload["safe"] == false
    error_result || payload
  end

  private
    def clean_choice(raw, allowed, field, label)
      return "" if raw.nil? || raw == ""
      unless raw.is_a?(String) && allowed.include?(raw)
        add(field, "#{label} is invalid", "is invalid")
        return ""
      end
      raw
    end

    def clean_boolean(raw, field, label)
      return nil if raw.nil?
      return raw if raw == true || raw == false

      add(field, "#{label} is invalid", "is invalid")
      nil
    end

    def clean_integer(raw, field, label, max)
      return nil if raw.nil?
      unless raw.is_a?(Integer) && raw.between?(0, max)
        add(field, "#{label} is invalid", "is invalid")
        return nil
      end
      raw
    end

    def clean_text(raw, field, label, max)
      return "" if raw.nil?
      unless raw.is_a?(String)
        add(field, "#{label} is invalid", "is invalid")
        return ""
      end

      cleaned = raw.strip
      add(field, "#{label} is too long", "is too long") if cleaned.length > max
      cleaned
    end

    def add(field, message, detail)
      @errors << { field: field, message: message, detail: detail }
    end

    def error_result
      return if @errors.empty?

      ordered = @errors.sort_by.with_index { |error, index| [ FIELD_ORDER.index(error[:field]) || FIELD_ORDER.length, index ] }
      {
        error: {
          code: "VALIDATION_ERROR",
          message: ordered.first[:message],
          details: ordered.each_with_object({}) do |error, details|
            (details[error[:field]] ||= []) << error[:detail]
          end
        }
      }
    end
end
