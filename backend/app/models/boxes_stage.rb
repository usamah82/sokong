class BoxesStage
  KEYS = %w[
    good_family_unit good_family_unit_gap basic_necessities basic_necessities_gap notes
  ].freeze

  def self.clean(input, enrolment:)
    new(input, enrolment).clean
  end

  def initialize(input, _enrolment)
    @input = input
    @errors = []
  end

  def clean
    payload = {
      "good_family_unit" => clean_box(@input["good_family_unit"], "good_family_unit", "Good family unit is invalid"),
      "good_family_unit_gap" => clean_text(@input["good_family_unit_gap"], "good_family_unit_gap"),
      "basic_necessities" => clean_box(@input["basic_necessities"], "basic_necessities", "Basic necessities is invalid"),
      "basic_necessities_gap" => clean_text(@input["basic_necessities_gap"], "basic_necessities_gap"),
      "notes" => clean_text(@input["notes"], "notes", "Anything else they said is invalid", "Anything else they said is too long")
    }
    error_result || payload
  end

  private
    def clean_box(raw, field, message)
      return nil if raw.nil?
      return raw if raw == true || raw == false

      add(field, message, "is invalid")
      nil
    end

    def clean_text(raw, field, invalid = "Gap is invalid", too_long = "Gap is too long")
      return "" if raw.nil?
      unless raw.is_a?(String)
        add(field, invalid, "is invalid")
        return ""
      end

      cleaned = raw.strip
      add(field, too_long, "is too long") if cleaned.length > 2000
      cleaned
    end

    def add(field, message, detail)
      @errors << { field: field, message: message, detail: detail }
    end

    def error_result
      return if @errors.empty?

      {
        error: {
          code: "VALIDATION_ERROR",
          message: @errors.first[:message],
          details: @errors.each_with_object({}) do |error, details|
            (details[error[:field]] ||= []) << error[:detail]
          end
        }
      }
    end
end
