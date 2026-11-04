class EnrolmentSubmission
  SELF_CONSENT = "Submission means the family consents. That consent is confirmed at the verification visit."
  ON_BEHALF_CONSENT = "This case is valid and will be checked at a visit. It may not be enrolled unless the family consents then."
  HELP_KEYS = %w[ food clothing school_supplies help_applying ].freeze
  GENDERS = %w[ male female unspecified ].freeze
  PHONE = /\A\+?[0-9]{8,15}\z/
  PHONE_CHARS = /[ \-\.\(\)]/
  LABELS = {
    "enroler_contact" => "Enroler contact",
    "email" => "Email",
    "on_behalf" => "On behalf",
    "place_name" => "Place name",
    "latitude" => "Latitude",
    "longitude" => "Longitude",
    "family_phone" => "Family phone",
    "how_to_find" => "How to find them",
    "help" => "Help",
    "other_help" => "Other help",
    "members" => "Members",
    "age" => "Age",
    "gender" => "Gender",
    "monthly_amount" => "Monthly amount",
    "job" => "Job",
    "name" => "Name",
    "description" => "Description",
    "in_education" => "In education",
    "working" => "Working",
    "role" => "Role"
  }.freeze

  def initialize(payload)
    @errors = []
    unless payload.is_a?(Hash)
      add("body", "is invalid", "Request body is invalid")
      @payload = {}
      @record = {}
      return
    end

    @payload = payload.deep_symbolize_keys
    @record = build
  end

  def valid?
    @errors.empty?
  end

  def error_envelope
    {
      error: {
        code: "VALIDATION_ERROR",
        message: @errors.first[:message],
        details: details
      }
    }
  end

  def save!
    raise ArgumentError, "Enrolment submission is invalid" unless valid?

    Enrolment.record!(**@record)
  end

  private
    def build
      on_behalf = flag(:on_behalf)
      contact = required_phone(:enroler_contact)
      mail = email
      place = place_name
      validate_coordinates

      {
        on_behalf: on_behalf,
        consent_text: on_behalf ? ON_BEHALF_CONSENT : SELF_CONSENT,
        enroler_contact: contact,
        email: mail,
        place_name: place,
        latitude: nil,
        longitude: nil,
        family_phone: optional_phone(:family_phone),
        how_to_find: text(:how_to_find, @payload[:how_to_find], 2_000),
        other_help: text(:other_help, @payload[:other_help], 500),
        help: help_keys,
        members: members
      }
    end

    def flag(key, source = @payload)
      return false unless source.key?(key)

      value = source[key]
      return value if value == true || value == false

      add(key, "is invalid")
      false
    end

    def required_phone(key)
      value = @payload[key]
      if value.nil? || (value.is_a?(String) && value.strip.empty?)
        add(key, "is required")
        return
      end

      normalize_phone(key, value)
    end

    def optional_phone(key)
      value = @payload[key]
      return "" if value.nil? || (value.is_a?(String) && value.strip.empty?)

      normalize_phone(key, value) || ""
    end

    def normalize_phone(key, value)
      unless value.is_a?(String)
        add(key, "is not a phone number")
        return
      end

      remainder = value.gsub(PHONE_CHARS, "")
      unless remainder.match?(PHONE)
        add(key, "is not a phone number")
        return
      end

      remainder
    end

    def email
      value = @payload[:email]
      return "" if value.nil?
      unless value.is_a?(String)
        add("email", "is invalid")
        return ""
      end

      trimmed = value.strip
      return "" if trimmed.empty?

      if trimmed.length > 254
        add("email", "is too long")
      elsif !trimmed.match?(URI::MailTo::EMAIL_REGEXP)
        add("email", "is invalid")
      end

      trimmed
    end

    def place_name
      value = @payload[:place_name]
      unless value.is_a?(String)
        add("place_name", "is required")
        return ""
      end

      collapsed = value.strip.gsub(/\s+/, " ")
      if collapsed.empty?
        add("place_name", "is required")
      elsif collapsed.length > 200
        add("place_name", "is too long")
      end

      collapsed
    end

    def validate_coordinates
      latitude_present = coordinate_present?(:latitude)
      longitude_present = coordinate_present?(:longitude)

      if latitude_present && !longitude_present
        add("longitude", "is required")
        return
      end
      if longitude_present && !latitude_present
        add("latitude", "is required")
        return
      end
      return unless latitude_present

      check_coordinate(:latitude, -90, 90)
      check_coordinate(:longitude, -180, 180)
    end

    def coordinate_present?(key)
      @payload.key?(key) && !@payload[key].nil?
    end

    def check_coordinate(key, minimum, maximum)
      value = @payload[key]
      unless value.is_a?(Numeric) && value.finite?
        add(key, "is not a number")
        return
      end

      add(key, "is out of range") unless value.between?(minimum, maximum)
    end

    def text(key, value, limit)
      return "" if value.nil?
      unless value.is_a?(String)
        add(key, "is invalid")
        return ""
      end

      trimmed = value.strip
      add(key, "is too long") if trimmed.length > limit
      trimmed
    end

    def help_keys
      value = @payload[:help]
      return [] if value.nil?
      unless value.is_a?(Array) && value.all? { |key| key.is_a?(String) && HELP_KEYS.include?(key) }
        add("help", "is invalid")
        return []
      end

      value.uniq
    end

    def members
      value = @payload[:members]
      unless value.is_a?(Array) && value.any?
        add("members", "are required")
        return []
      end

      cleaned = value.map { |member| clean_member(member) }
      heads = value.count { |member| member.is_a?(Hash) && member.symbolize_keys[:role] == "head" }
      if heads > 1
        add("members", "has more than one head", "A family has one head")
      elsif heads.zero?
        add("members", "needs a head", "A family needs a head")
      end

      cleaned.compact
    end

    def clean_member(member)
      unless member.is_a?(Hash)
        add("members", "is invalid", "Member is invalid")
        return
      end

      member = member.symbolize_keys
      working = flag(:working, member)

      {
        role: role(member[:role]),
        name: member_name(member),
        age: integer_field("age", member[:age], 0, 130),
        gender: gender(member[:gender]),
        description: text("description", member[:description], 2_000),
        in_education: flag(:in_education, member),
        working: working,
        job: working ? text("job", member[:job], 200) : "",
        monthly_amount: working ? integer_field("monthly_amount", member[:monthly_amount], 0, 999_999_999) : nil
      }
    end

    def role(value)
      return value if value == "head" || value == "member"

      add("role", "is invalid")
      nil
    end

    def member_name(member)
      value = member[:name]
      unless value.is_a?(String)
        add("name", "is required", name_message(member))
        return ""
      end

      trimmed = value.strip
      if trimmed.empty?
        add("name", "is required", name_message(member))
      elsif trimmed.length > 200
        add("name", "is too long")
      end

      trimmed
    end

    def name_message(member)
      member[:role] == "head" ? "Head name is required" : "Member name is required"
    end

    def gender(value)
      if value.nil? || value == ""
        add("gender", "is required")
        return
      end
      unless value.is_a?(String) && GENDERS.include?(value)
        add("gender", "is invalid")
        return
      end

      value
    end

    def integer_field(key, value, minimum, maximum)
      return nil if value.nil? || value == ""
      unless value.is_a?(Integer)
        add(key, "is not an integer")
        return
      end
      unless value.between?(minimum, maximum)
        add(key, "is out of range")
        return
      end

      value
    end

    def details
      @errors.each_with_object({}) do |error, grouped|
        (grouped[error[:key]] ||= []) << error[:detail]
      end
    end

    def add(key, detail, message = nil)
      @errors << {
        key: key.to_s,
        detail: detail,
        message: message || "#{LABELS.fetch(key.to_s)} #{detail}"
      }
    end
end
