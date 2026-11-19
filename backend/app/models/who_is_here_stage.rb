class WhoIsHereStage
  KEYS = %w[people others_stay others_stay_detail care_for_parents care_for_parents_detail notes].freeze
  DOCUMENT_KINDS = %w[national_id social_security passport birth_certificate other].freeze
  GENDERS = %w[male female unspecified].freeze
  RELATIONSHIPS = %w[spouse child parent other].freeze
  IDENTITIES = %w[verified not_verified no_papers].freeze
  FIELD_ORDER = %w[
    person_id family_member_id head name birth_date gender phone
    kind number other_label origin relationship identity absent absent_since absent_reason
    others_stay others_stay_detail care_for_parents care_for_parents_detail notes
  ].freeze
  UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  DATE = /\A(\d{4})-(\d{2})-(\d{2})\z/
  PHONE_MESSAGE = "Enter a phone number, for example +60 12-345 6789."

  def self.clean(input, enrolment:)
    new(input, enrolment).clean
  end

  def initialize(input, enrolment)
    @input = input
    @enrolment = enrolment
    @errors = []
    @stop = false
  end

  def clean
    people = clean_people
    return error_result if @stop

    payload = {
      "people" => people,
      "others_stay" => clean_boolean(@input["others_stay"], "others_stay", "Does anyone else stay"),
      "others_stay_detail" => follow_up(@input["others_stay"], @input["others_stay_detail"], "others_stay_detail", "Who, and why?"),
      "care_for_parents" => clean_boolean(@input["care_for_parents"], "care_for_parents", "Do you have to take care of elderly parents"),
      "care_for_parents_detail" => follow_up(
        @input["care_for_parents"], @input["care_for_parents_detail"], "care_for_parents_detail", "Who, and what do you do for them?"
      ),
      "notes" => clean_text(@input["notes"], max: 2000, field: "notes", label: "Anything else they said")
    }
    error_result || payload
  end

  private
    def clean_people
      raw_people = @input["people"]
      unless raw_people.is_a?(Array)
        add("family_member_id", "Person is required", "is required")
        @stop = true
        return []
      end

      people = []
      raw_people.each do |person|
        person = hash_of(person)
        unless person
          add("person_id", "Person is invalid", "is invalid")
          next
        end
        people << clean_person(person)
      end

      check_duplicates(people)
      check_missing(people)
      people.each { |person| check_head(person) }
      people.each { |person| person.delete("_member_known") }
      people
    end

    def clean_person(person)
      person_id = clean_uuid(person["person_id"])
      member_id, member_known = clean_member_id(person["family_member_id"])
      head = clean_boolean(person["head"], "head", "Head", allow_nil: false)
      name = clean_text(person["name"], max: 200, field: "name", label: "Full name", required: true)
      birth_date = clean_date(person["birth_date"], "birth_date", "Birth date")
      gender = clean_choice(person["gender"], GENDERS, "gender", "Gender")
      phone = clean_phone(person["phone"])
      documents = clean_documents(person["documents"])
      child = !head_member?(member_id) && person["relationship"] == "child"
      origin = child ? "" : clean_text(person["origin"], max: 200, field: "origin", label: "From where?")
      relationship = head_member?(member_id) ? "" : clean_choice(person["relationship"], RELATIONSHIPS, "relationship", "Relationship")
      identity = clean_choice(person["identity"], IDENTITIES, "identity", "Identity check")
      absent = clean_boolean(person["absent"], "absent", "Absent")
      since = ""
      reason = ""
      if absent == true
        since = clean_date(person["absent_since"], "absent_since", "Since when")
        reason = clean_text(person["absent_reason"], max: 2000, field: "absent_reason", label: "Why")
      end

      {
        "person_id" => person_id,
        "family_member_id" => member_id,
        "head" => head,
        "name" => name,
        "birth_date" => birth_date,
        "gender" => gender,
        "phone" => phone,
        "documents" => documents,
        "origin" => origin,
        "relationship" => relationship,
        "identity" => identity,
        "absent" => absent,
        "absent_since" => since,
        "absent_reason" => reason,
        "_member_known" => member_known
      }
    end

    def check_duplicates(people)
      seen_ids = []
      seen_members = []
      people.each do |person|
        person_id = person["person_id"]
        if person_id.present?
          add("person_id", "Person is invalid", "is invalid") if seen_ids.include?(person_id)
          seen_ids << person_id
        end

        member_id = person["family_member_id"]
        next if member_id.nil?

        add("family_member_id", "Person is invalid", "is invalid") if seen_members.include?(member_id)
        seen_members << member_id
      end
    end

    def check_missing(people)
      present = people.filter_map { |person| person["family_member_id"] }
      return if (@enrolment.members.map(&:id) - present).empty?

      add("family_member_id", "Person is required", "is required")
    end

    def check_head(person)
      return unless person["head"] == true || person["head"] == false
      return if person["family_member_id"].nil? && !person["_member_known"]

      expected = head_member?(person["family_member_id"])
      return if person["head"] == expected

      add("relationship", "Relationship is invalid", "is invalid")
    end

    def clean_documents(raw)
      unless raw.is_a?(Array)
        add("kind", "Document is invalid", "is invalid")
        return []
      end

      raw.filter_map do |document|
        document = hash_of(document)
        unless document
          add("kind", "Document is invalid", "is invalid")
          next
        end

        kind = document["kind"]
        add("kind", "Document is invalid", "is invalid") unless DOCUMENT_KINDS.include?(kind)
        number = clean_text(document["number"], max: 100, field: "number", label: "Document number", required: true)
        label = ""
        if kind == "other"
          label = clean_text(document["other_label"], max: 100, field: "other_label", label: "What document?", required: true)
        end

        { "kind" => kind, "number" => number, "other_label" => label }
      end
    end

    def clean_uuid(value)
      unless value.is_a?(String) && value.match?(UUID)
        add("person_id", "Person is invalid", "is invalid")
        return ""
      end
      value
    end

    def clean_member_id(value)
      return [ nil, true ] if value.nil? || value == ""

      unless value.is_a?(String) && member_ids.include?(value)
        add("family_member_id", "Person is invalid", "is invalid")
        return [ nil, false ]
      end
      [ value, true ]
    end

    def head_member?(member_id)
      return false if member_id.blank?

      @enrolment.members.find { |member| member.id == member_id }&.role == "head"
    end

    def member_ids
      @member_ids ||= @enrolment.members.map(&:id)
    end

    def clean_phone(raw)
      return "" if raw.nil? || raw == ""
      unless raw.is_a?(String)
        add("phone", PHONE_MESSAGE, "is invalid")
        return ""
      end

      normalized = raw.gsub(/[ \-.()]/, "")
      return "" if normalized.empty?
      add("phone", PHONE_MESSAGE, "is invalid") unless normalized.match?(EnrolmentSubmission::PHONE)
      normalized
    end

    def clean_date(raw, field, label)
      return "" if raw.nil? || raw == ""
      match = raw.is_a?(String) ? DATE.match(raw) : nil
      unless match && Date.valid_date?(match[1].to_i, match[2].to_i, match[3].to_i)
        add(field, "#{label} is invalid", "is invalid")
        return ""
      end
      raw
    end

    def clean_choice(raw, allowed, field, label)
      return "" if raw.nil? || raw == ""
      unless raw.is_a?(String) && allowed.include?(raw)
        message = field == "identity" ? "Identity check is invalid" : "#{label} is invalid"
        add(field, message, "is invalid")
        return ""
      end
      raw
    end

    def clean_boolean(raw, field, label, allow_nil: true)
      if raw.nil?
        add(field, "#{label} is invalid", "is invalid") unless allow_nil
        return nil
      end
      return raw if raw == true || raw == false

      add(field, "#{label} is invalid", "is invalid")
      nil
    end

    def clean_text(raw, max:, field:, label:, required: false)
      if raw.nil?
        add(field, "#{label} is required", "is required") if required
        return ""
      end
      unless raw.is_a?(String)
        add(field, "#{label} is invalid", "is invalid")
        return ""
      end

      cleaned = raw.strip
      if cleaned.empty? && required
        add(field, "#{label} is required", "is required")
      elsif cleaned.length > max
        add(field, "#{label} is too long", "is too long")
      end
      cleaned
    end

    def follow_up(flag, raw, field, label)
      return "" unless flag == true

      clean_text(raw, max: 2000, field: field, label: label)
    end

    def hash_of(value)
      value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      value if value.is_a?(Hash)
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
