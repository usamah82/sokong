class EnrolmentSubmission
  SELF_CONSENT = "Submission means the family consents. That consent is confirmed at the verification visit."
  ON_BEHALF_CONSENT = "This case is valid and will be checked at a visit. It may not be enrolled unless the family consents then."

  HELP_KEYS = %w[food clothing school_supplies help_applying].freeze
  GENDERS = %w[male female unspecified].freeze
  ROLES = %w[head member].freeze
  PHONE = /\A\+?[0-9]{8,15}\z/

  def initialize(params)
    @params = params
    @errors = []
  end

  def error_envelope
    prepare
    return if @errors.empty?

    {
      code: "VALIDATION_ERROR",
      message: @errors.first[:message],
      details: @errors.each_with_object({}) do |error, details|
        (details[error[:field]] ||= []) << error[:detail]
      end
    }
  end

  def save
    raise ArgumentError, error_envelope[:message] if error_envelope

    Enrolment.record!(**@attributes)
  end

  private
    def prepare
      return if defined?(@attributes)

      @attributes = { latitude: nil, longitude: nil }
      @attributes[:enroler_contact] = phone("enroler_contact", required: true, label: "Enroler contact")
      @attributes[:email] = email
      @attributes[:place_name] = text("place_name", max: 200, label: "Place name", required: true, collapse: true)
      @attributes[:family_phone] = phone("family_phone", required: false, label: "Family phone")
      @attributes[:how_to_find] = text("how_to_find", max: 2000, label: "How to find them")
      @attributes[:other_help] = text("other_help", max: 500, label: "Other help")
      @attributes[:help] = help_keys
      coordinates
      on_behalf
      @attributes[:members] = members
    end

    def phone(key, required:, label:)
      raw = value(@params, key)
      if raw.nil? || (raw.is_a?(String) && raw.gsub(/[ \-.()]/, "").empty?)
        add(key, "#{label} is required", "is required") if required
        return ""
      end
      unless raw.is_a?(String)
        add(key, "#{label} is not a phone number", "is not a phone number")
        return ""
      end

      normalized = raw.gsub(/[ \-.()]/, "")
      add(key, "#{label} is not a phone number", "is not a phone number") unless normalized.match?(PHONE)
      normalized
    end

    def email
      raw = value(@params, "email")
      return "" if raw.nil? || raw == ""
      unless raw.is_a?(String)
        add("email", "Email is invalid", "is invalid")
        return ""
      end

      cleaned = raw.strip
      return "" if cleaned.empty?
      if cleaned.length > 254
        add("email", "Email is too long", "is too long")
      elsif !cleaned.match?(URI::MailTo::EMAIL_REGEXP)
        add("email", "Email is invalid", "is invalid")
      end
      cleaned
    end

    def text(key, max:, label:, required: false, collapse: false)
      raw = value(@params, key)
      if raw.nil?
        add(key, "#{label} is required", "is required") if required
        return ""
      end
      unless raw.is_a?(String)
        add(key, "#{label} is invalid", "is invalid")
        return ""
      end

      cleaned = raw.strip
      cleaned = cleaned.gsub(/\s+/, " ") if collapse
      if cleaned.empty?
        add(key, "#{label} is required", "is required") if required
        return ""
      end
      add(key, "#{label} is too long", "is too long") if cleaned.length > max
      cleaned
    end

    def help_keys
      raw = value(@params, "help")
      return [] if raw.nil?
      unless raw.is_a?(Array)
        add("help", "Help is invalid", "is invalid")
        return []
      end

      raw.each do |key|
        next if key.is_a?(String) && HELP_KEYS.include?(key)

        add("help", "Help is not included", "is not included")
        break
      end
      raw
    end

    def coordinates
      latitude = value(@params, "latitude")
      longitude = value(@params, "longitude")
      return if latitude.nil? && longitude.nil?
      if latitude.nil? || longitude.nil?
        add("latitude", "Latitude and longitude must both be present", "must be present with longitude")
        return
      end

      number("latitude", latitude, -90..90, "Latitude")
      number("longitude", longitude, -180..180, "Longitude")
    end

    def number(field, raw, range, label)
      unless raw.is_a?(Numeric) && raw.finite?
        add(field, "#{label} is not a number", "is not a number")
        return
      end
      return if range.cover?(raw)

      add(field, "#{label} is out of range", "is out of range")
    end

    def on_behalf
      raw = value(@params, "on_behalf")
      unless raw == true || raw == false
        add("on_behalf", "On behalf must be true or false", "must be true or false")
        raw = false
      end
      @attributes[:on_behalf] = raw
      @attributes[:consent_text] = raw ? ON_BEHALF_CONSENT : SELF_CONSENT
    end

    def members
      raw = value(@params, "members")
      unless raw.is_a?(Array) && raw.any?
        add("members", "Members are required", "are required")
        return []
      end

      cleaned = raw.map { |member| member_attributes(member) }
      heads = cleaned.count { |member| member[:role] == "head" }
      if heads.zero?
        add("members", "Members need one head", "needs one head")
      elsif heads > 1
        add("members", "Members have more than one head", "has more than one head")
      end
      cleaned
    end

    def member_attributes(member)
      blank = { role: nil, name: "", age: nil, gender: "unspecified", description: "", in_education: false, working: false, job: "", monthly_amount: nil }
      unless member.respond_to?(:key?)
        add("members", "Members are invalid", "is invalid")
        return blank
      end

      role = value(member, "role")
      unless role.is_a?(String) && ROLES.include?(role)
        add("members", "Member role is not included", "role is not included")
        role = nil
      end
      working = flag(member, "working", "Working")

      {
        role: role,
        name: member_name(member, role),
        age: integer_field(member, "age", 0..130, "Age", "age"),
        gender: gender(member),
        description: member_text(member, "description", 2000, "Description"),
        in_education: flag(member, "in_education", "In education"),
        working: working,
        job: working ? member_text(member, "job", 200, "Job") : "",
        monthly_amount: working ? integer_field(member, "monthly_amount", 0..999_999_999, "Monthly amount", "monthly amount") : nil
      }
    end

    def member_name(member, role)
      raw = value(member, "name")
      head = role == "head"
      label = head ? "Head name" : "Member name"
      detail = head ? "head name" : "name"
      unless raw.is_a?(String) && raw.strip.present?
        add("members", "#{label} is required", "#{detail} is required")
        return ""
      end

      cleaned = raw.strip
      add("members", "#{label} is too long", "#{detail} is too long") if cleaned.length > 200
      cleaned
    end

    def gender(member)
      raw = value(member, "gender")
      return raw if raw.is_a?(String) && GENDERS.include?(raw)

      add("members", "Gender is not included", "gender is not included")
      "unspecified"
    end

    def integer_field(source, key, range, label, detail)
      return nil unless present?(source, key)

      raw = value(source, key)
      return nil if raw.nil? || raw == ""
      unless raw.is_a?(Integer)
        add("members", "#{label} is not an integer", "#{detail} is not an integer")
        return nil
      end
      add("members", "#{label} is out of range", "#{detail} is out of range") unless range.cover?(raw)
      raw
    end

    def flag(member, key, label)
      return false unless present?(member, key)

      raw = value(member, key)
      return raw if raw == true || raw == false

      add("members", "#{label} must be true or false", "#{key} must be true or false")
      false
    end

    def member_text(member, key, max, label)
      return "" unless present?(member, key)

      raw = value(member, key)
      return "" if raw.nil?
      unless raw.is_a?(String)
        add("members", "#{label} is invalid", "#{key} is invalid")
        return ""
      end

      cleaned = raw.strip
      add("members", "#{label} is too long", "#{key} is too long") if cleaned.length > max
      cleaned
    end

    def present?(source, key)
      source.key?(key) || source.key?(key.to_sym)
    end

    def value(source, key)
      if source.key?(key)
        source[key]
      elsif source.key?(key.to_sym)
        source[key.to_sym]
      end
    end

    def add(field, message, detail)
      @errors << { field: field.to_s, message: message, detail: detail }
    end
end
