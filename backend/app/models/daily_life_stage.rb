class DailyLifeStage
  KEYS = %w[people].freeze
  UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  FIELD_ORDER = %w[
    person_id working job monthly_amount previous_jobs wished_work skills
    in_school school_going school_where school_travel
  ].freeze
  AMOUNT_MESSAGE = "Ringgit per month is invalid"

  def self.clean(input, enrolment:)
    new(input, enrolment).clean
  end

  def initialize(input, _enrolment)
    @input = input
    @errors = []
  end

  def clean
    people = clean_people
    return error_result if @stop

    error_result || { "people" => people }
  end

  private
    def clean_people
      raw = @input["people"]
      unless raw.is_a?(Array)
        add("person_id", "Person is invalid", "is invalid")
        @stop = true
        return []
      end

      people = []
      raw.each do |person|
        person = person.to_unsafe_h if person.respond_to?(:to_unsafe_h)
        unless person.is_a?(Hash)
          add("person_id", "Person is invalid", "is invalid")
          next
        end
        people << clean_person(person)
      end
      seen = []
      people.each do |person|
        next if person["person_id"].blank?

        add("person_id", "Person is invalid", "is invalid") if seen.include?(person["person_id"])
        seen << person["person_id"]
      end
      people
    end

    def clean_person(person)
      person_id = clean_uuid(person["person_id"])
      working = clean_boolean(person["working"], "working", "Are you working?")
      job = ""
      amount = nil
      previous = ""
      wished = ""
      if working == true
        job = clean_text(person["job"], "job", "What job?", 200)
        amount = clean_amount(person["monthly_amount"])
        previous = clean_text(person["previous_jobs"], "previous_jobs", "Any previous jobs?", 2000)
        wished = clean_text(person["wished_work"], "wished_work", "If you wish for a new job or income, what would that be?", 2000)
      end
      skills = clean_text(person["skills"], "skills", "Any skills to highlight?", 2000)
      in_school = clean_boolean(person["in_school"], "in_school", "Are you in school?")
      going = ""
      where = ""
      travel = ""
      if in_school == true
        going = clean_text(person["school_going"], "school_going", "How is school going?", 2000)
        where = clean_text(person["school_where"], "school_where", "Where is school?", 200)
        travel = clean_text(person["school_travel"], "school_travel", "How do you get there?", 2000)
      end

      {
        "person_id" => person_id,
        "working" => working,
        "job" => job,
        "monthly_amount" => amount,
        "previous_jobs" => previous,
        "wished_work" => wished,
        "skills" => skills,
        "in_school" => in_school,
        "school_going" => going,
        "school_where" => where,
        "school_travel" => travel
      }
    end

    def clean_uuid(value)
      unless value.is_a?(String) && value.match?(UUID)
        add("person_id", "Person is invalid", "is invalid")
        return ""
      end
      value
    end

    def clean_amount(raw)
      return nil if raw.nil?
      unless raw.is_a?(Integer) && raw.between?(0, 999_999_999)
        add("monthly_amount", AMOUNT_MESSAGE, "is invalid")
        return nil
      end
      raw
    end

    def clean_boolean(raw, field, label)
      return nil if raw.nil?
      return raw if raw == true || raw == false

      add(field, "#{label} is invalid", "is invalid")
      nil
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
