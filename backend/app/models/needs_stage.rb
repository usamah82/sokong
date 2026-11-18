class NeedsStage
  KEYS = %w[need_most consent_given notes].freeze

  def self.clean(input, enrolment:)
    new(input, enrolment).clean
  end

  def initialize(input, _enrolment)
    @input = input
    @errors = []
  end

  def clean
    payload = {
      "need_most" => clean_text(@input["need_most"], "need_most", "What do you need most?"),
      "consent_given" => clean_consent(@input["consent_given"]),
      "notes" => clean_text(@input["notes"], "notes", "Anything else they said")
    }
    error_result || payload
  end

  private
    def clean_consent(raw)
      return nil if raw.nil?
      return raw if raw == true || raw == false

      add("consent_given", "Consent is invalid", "is invalid")
      nil
    end

    def clean_text(raw, field, label)
      return "" if raw.nil?
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
