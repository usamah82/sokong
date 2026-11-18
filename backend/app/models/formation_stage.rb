class FormationStage
  KEYS = %w[started_year how_it_started notes].freeze
  YEAR_MESSAGE = "Enter the year, for example 2008."

  def self.clean(input, enrolment:)
    new(input, enrolment).clean
  end

  def initialize(input, enrolment)
    @input = input
    @enrolment = enrolment
    @errors = []
  end

  def clean
    payload = {
      "started_year" => clean_year(@input["started_year"]),
      "how_it_started" => clean_text(@input["how_it_started"], "how_it_started", "How did it start?"),
      "notes" => clean_text(@input["notes"], "notes", "Anything else they said")
    }
    error_result || payload
  end

  private
    def clean_year(raw)
      return nil if raw.nil?
      current = Time.current.utc.year
      unless raw.is_a?(Integer) && raw.between?(1900, current)
        add("started_year", YEAR_MESSAGE, "is invalid")
        return nil
      end
      raw
    end

    def clean_text(raw, field, label)
      if raw.nil?
        return ""
      end
      unless raw.is_a?(String)
        add(field, "#{label} is invalid", "is invalid")
        return ""
      end

      cleaned = raw.strip
      add(field, "#{label} is too long", "is too long") if cleaned.length > 2000
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
