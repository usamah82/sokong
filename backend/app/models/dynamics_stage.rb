class DynamicsStage
  KEYS = %w[hard_week who_steps_in children_at_home notes].freeze

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
      "hard_week" => clean_text(@input["hard_week"], "hard_week", "What does a hard week look like here?"),
      "who_steps_in" => clean_text(@input["who_steps_in"], "who_steps_in", "When someone here needs help, who steps in?"),
      "children_at_home" => children(@input["children_at_home"]),
      "notes" => clean_text(@input["notes"], "notes", "Anything else they said")
    }
    error_result || payload
  end

  private
    def children(raw)
      return "" unless child_saved?

      clean_text(raw, "children_at_home", "How are the children at home?")
    end

    def child_saved?
      people = @enrolment.verification&.who_is_here&.dig("people")
      return false unless people.is_a?(Array)

      people.any? { |person| person.is_a?(Hash) && person["relationship"] == "child" }
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
