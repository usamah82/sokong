class WhoIsHereStage
  DOCUMENT_KINDS = %w[national_id social_security passport birth_certificate other].freeze
  GENDERS = %w[male female unspecified].freeze
  RELATIONSHIPS = %w[spouse child parent other].freeze
  IDENTITIES = %w[verified not_verified no_papers].freeze
  UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  DATE = /\A(\d{4})-(\d{2})-(\d{2})\z/
  PHONE_MESSAGE = "Enter a phone number, for example +60 12-345 6789."

  def self.clean(input, enrolment:)
    new(input, enrolment).clean
  end

  def initialize(input, enrolment)
    @input = input
    @enrolment = enrolment
    @error = nil
  end

  def clean
    people = clean_people
    return error_result if @error

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
    return error_result if @error

    payload
  end

  def error_result
    { error: @error }
  end

  private
    def clean_people
      raw_people = @input["people"]
      unless raw_people.is_a?(Array)
        fail!("Person is required", "family_member_id", "is required")
        return
      end

      people = raw_people.map { |person| clean_person(person) }
      return if @error

      seen_ids = []
      seen_members = []
      people.each do |person|
        if seen_ids.include?(person["person_id"])
          fail!("Person is invalid", "person_id", "is invalid")
          return
        end
        seen_ids << person["person_id"]
        member_id = person["family_member_id"]
        next if member_id.nil?

        if seen_members.include?(member_id)
          fail!("Person is invalid", "family_member_id", "is invalid")
          return
        end
        seen_members << member_id
      end

      missing = @enrolment.members.map(&:id) - seen_members
      if missing.any?
        fail!("Person is required", "family_member_id", "is required")
        return
      end

      check_head(people)
      return if @error

      people
    end

    def clean_person(person)
      person = person.to_unsafe_h if person.respond_to?(:to_unsafe_h)
      unless person.is_a?(Hash)
        fail!("Person is invalid", "person_id", "is invalid")
        return
      end

      person_id = clean_uuid(person["person_id"])
      return if @error

      member_id = clean_member_id(person["family_member_id"])
      return if @error

      head = clean_boolean(person["head"], "head", "Head")
      return if @error

      name = clean_text(person["name"], max: 200, field: "name", label: "Full name", required: true)
      return if @error

      birth_date = clean_date(person["birth_date"], "birth_date", "Birth date")
      return if @error

      gender = clean_choice(person["gender"], GENDERS, "gender", "Gender")
      return if @error

      phone = clean_phone(person["phone"])
      return if @error

      documents = clean_documents(person["documents"])
      return if @error

      relationship = clean_relationship(person["relationship"], member_id)
      return if @error

      origin = clean_text(person["origin"], max: 200, field: "origin", label: "From where?")
      return if @error
      origin = "" if relationship == "child"

      identity = clean_choice(person["identity"], IDENTITIES, "identity", "Identity check")
      return if @error

      absent = clean_boolean(person["absent"], "absent", "Absent")
      return if @error

      since = clean_date(person["absent_since"], "absent_since", "Since when")
      return if @error
      reason = clean_text(person["absent_reason"], max: 2000, field: "absent_reason", label: "Why")
      return if @error
      unless absent == true
        since = ""
        reason = ""
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
        "relationship" => head_member?(member_id) ? "" : relationship,
        "identity" => identity,
        "absent" => absent,
        "absent_since" => since,
        "absent_reason" => reason
      }
    end

    def check_head(people)
      head_id = @enrolment.members.find { |member| member.role == "head" }&.id
      people.each do |person|
        expected = person["family_member_id"] == head_id
        next if person["head"] == expected

        fail!("Relationship is invalid", "relationship", "is invalid")
        return
      end
    end

    def clean_documents(raw)
      unless raw.is_a?(Array)
        fail!("Document is invalid", "kind", "is invalid")
        return []
      end

      raw.map do |document|
        document = document.to_unsafe_h if document.respond_to?(:to_unsafe_h)
        unless document.is_a?(Hash)
          fail!("Document is invalid", "kind", "is invalid")
          return
        end

        kind = document["kind"]
        unless DOCUMENT_KINDS.include?(kind)
          fail!("Document is invalid", "kind", "is invalid")
          return
        end

        number = clean_text(document["number"], max: 100, field: "number", label: "Document number", required: true)
        return if @error

        label = clean_text(document["other_label"], max: 100, field: "other_label", label: "What document?", required: kind == "other")
        return if @error

        {
          "kind" => kind,
          "number" => number,
          "other_label" => kind == "other" ? label : ""
        }
      end
    end

    def clean_uuid(value)
      unless value.is_a?(String) && value.match?(UUID)
        fail!("Person is invalid", "person_id", "is invalid")
        return
      end
      value
    end

    def clean_member_id(value)
      return nil if value.nil? || value == ""

      unless value.is_a?(String) && @enrolment.members.map(&:id).include?(value)
        fail!("Person is invalid", "family_member_id", "is invalid")
        return
      end
      value
    end

    def clean_relationship(value, member_id)
      return "" if head_member?(member_id)

      clean_choice(value, RELATIONSHIPS, "relationship", "Relationship")
    end

    def head_member?(member_id)
      return false if member_id.nil?

      @enrolment.members.find { |member| member.id == member_id }&.role == "head"
    end

    def clean_phone(raw)
      return "" if raw.nil? || raw == ""
      unless raw.is_a?(String)
        fail!(PHONE_MESSAGE, "phone", "is invalid")
        return ""
      end

      normalized = raw.gsub(/[ \-.()]/, "")
      return "" if normalized.empty?
      unless normalized.match?(EnrolmentSubmission::PHONE)
        fail!(PHONE_MESSAGE, "phone", "is invalid")
      end
      normalized
    end

    def clean_date(raw, field, label)
      return "" if raw.nil? || raw == ""
      match = raw.is_a?(String) ? DATE.match(raw) : nil
      unless match && Date.valid_date?(match[1].to_i, match[2].to_i, match[3].to_i)
        fail!("#{label} is invalid", field, "is invalid")
        return ""
      end
      raw
    end

    def clean_choice(raw, allowed, field, label)
      return "" if raw.nil? || raw == ""
      unless raw.is_a?(String) && allowed.include?(raw)
        message = field == "identity" ? "Identity check is invalid" : "#{label} is invalid"
        fail!(message, field, "is invalid")
        return ""
      end
      raw
    end

    def clean_boolean(raw, field, label)
      return nil if raw.nil?
      return raw if raw == true || raw == false

      fail!("#{label} is invalid", field, "is invalid")
      nil
    end

    def clean_text(raw, max:, field:, label:, required: false)
      if raw.nil?
        fail!("#{label} is required", field, "is required") if required
        return ""
      end
      unless raw.is_a?(String)
        fail!("#{label} is invalid", field, "is invalid")
        return ""
      end

      cleaned = raw.strip
      if cleaned.empty? && required
        fail!("#{label} is required", field, "is required")
      elsif cleaned.length > max
        fail!("#{label} is too long", field, "is too long")
      end
      cleaned
    end

    def follow_up(flag, raw, field, label)
      text = clean_text(raw, max: 2000, field: field, label: label)
      flag == true ? text : ""
    end

    def fail!(message, field, detail)
      return if @error

      @error = {
        code: "VALIDATION_ERROR",
        message: message,
        details: { field => [ detail ] }
      }
    end
end
