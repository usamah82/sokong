require "test_helper"

class EnrolmentsTest < ActionDispatch::IntegrationTest
  SELF_CONSENT = "Submission means the family consents. That consent is confirmed at the verification visit."
  ON_BEHALF_CONSENT = "This case is valid and will be checked at a visit. It may not be enrolled unless the family consents then."

  test "a named head with empty optional fields creates an enrolment and a second post creates another" do
    assert_difference [ "Enrolment.count", "FamilyUnit.count", "FamilyMember.count", "Locality.count" ], 1 do
      post "/enrolments", params: valid_enrolment, as: :json
    end

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal "+60123456789", enrolment.enroler_contact
    assert_equal "", enrolment.email
    assert_equal "Kampung Baru", enrolment.place_name
    assert_nil enrolment.latitude
    assert_nil enrolment.longitude
    assert_equal "", enrolment.family_phone
    assert_equal "", enrolment.how_to_find
    assert_equal [], enrolment.help
    assert_equal "", enrolment.other_help
    assert_equal false, enrolment.on_behalf
    assert_equal SELF_CONSENT, enrolment.consent_text
    assert_nil enrolment.visit_at
    assert_equal "Kampung Baru", enrolment.locality.name
    assert_nil enrolment.locality.latitude
    assert_nil enrolment.locality.longitude
    assert_nil enrolment.locality.radius_metres
    head = enrolment.members.sole
    assert_equal "head", head.role
    assert_equal "Siti", head.name
    assert_nil head.age
    assert_equal "unspecified", head.gender
    assert_equal "", head.description
    assert_equal false, head.in_education
    assert_equal false, head.working
    assert_equal "", head.job
    assert_nil head.monthly_amount
    assert_equal enrolment_json(enrolment), response.parsed_body

    assert_difference [ "Enrolment.count", "FamilyUnit.count", "FamilyMember.count" ], 1 do
      assert_no_difference "Locality.count" do
        post "/enrolments", params: valid_enrolment.merge(
          on_behalf: true,
          consent_text: SELF_CONSENT,
          enroler_contact: "012-345 6789",
          place_name: "kampung baru",
          family_phone: "012-345 6789",
          members: [ { role: "head", name: "Aminah", gender: "female", age: 30 } ]
        ), as: :json
      end
    end

    assert_response :created
    second = Enrolment.order(:created_at).last
    assert_not_equal enrolment.family_unit_id, second.family_unit_id
    assert_equal enrolment.locality_id, second.locality_id
    assert_equal true, second.on_behalf
    assert_equal ON_BEHALF_CONSENT, second.consent_text
    assert_equal "0123456789", second.enroler_contact
    assert_equal "0123456789", second.family_phone
    assert_equal "kampung baru", second.place_name
    assert_nil second.latitude
    assert_nil second.longitude
    assert_nil second.visit_at
    assert_equal 30, second.members.sole.age
    assert_equal enrolment_json(second), response.parsed_body
  end

  test "a missing enroler phone returns 422 and saves nothing" do
    body = valid_enrolment
    body.delete(:enroler_contact)

    assert_rejected body, "Enroler contact is required", "enroler_contact" => [ "is required" ]
  end

  test "a contact that is not a phone returns 422 and saves nothing" do
    [ "Mary at the shop", "123", "phone: 0123456789" ].each do |contact|
      body = valid_enrolment
      body[:enroler_contact] = contact

      assert_rejected body, "Enroler contact is not a phone number", "enroler_contact" => [ "is not a phone number" ]
    end
  end

  test "a missing place name returns 422 and saves nothing" do
    body = valid_enrolment
    body[:place_name] = "   "

    assert_rejected body, "Place name is required", "place_name" => [ "is required" ]
  end

  test "a missing head name returns 422 and saves nothing" do
    body = valid_enrolment
    body[:members][0][:name] = " "

    assert_rejected body, "Head name is required", "members" => [ "head name is required" ]
  end

  test "a gender outside the three values returns 422 and saves nothing" do
    body = valid_enrolment
    body[:members][0][:gender] = "other"

    assert_rejected body, "Gender is not included", "members" => [ "gender is not included" ]
  end

  test "a non-integer age returns 422 and saves nothing" do
    [ 8.5, "10" ].each do |age|
      body = valid_enrolment
      body[:members][0][:age] = age

      assert_rejected body, "Age is not an integer", "members" => [ "age is not an integer" ]
    end
  end

  test "a non-integer monthly amount returns 422 and saves nothing" do
    [ "about 800", 800.5 ].each do |amount|
      body = valid_enrolment
      body[:members][0][:working] = true
      body[:members][0][:monthly_amount] = amount

      assert_rejected body, "Monthly amount is not an integer", "members" => [ "monthly amount is not an integer" ]
    end
  end

  test "a help key outside the four returns 422 and saves nothing" do
    body = valid_enrolment
    body[:help] = [ "food", "shelter" ]

    assert_rejected body, "Help is not included", "help" => [ "is not included" ]
  end

  test "more than 20 members returns 422 and saves nothing" do
    body = valid_enrolment
    body[:members] = [ { role: "head", name: "Siti", gender: "unspecified" } ]
    20.times do |index|
      body[:members] << { role: "member", name: "Child #{index}", gender: "unspecified" }
    end

    assert_rejected body, "Members are too many", "members" => [ "are too many" ]
  end

  test "20 members are saved" do
    body = valid_enrolment
    body[:members] = [ { role: "head", name: "Siti", gender: "unspecified" } ]
    19.times do |index|
      body[:members] << { role: "member", name: "Child #{index}", gender: "unspecified" }
    end

    assert_difference "FamilyMember.count", 20 do
      post "/enrolments", params: body, as: :json
    end

    assert_response :created
  end

  test "20 members at the field limits still fit" do
    member = {
      role: "member",
      name: "n" * 200,
      gender: "unspecified",
      age: 130,
      description: "d" * 2000,
      in_education: true,
      working: true,
      job: "j" * 200,
      monthly_amount: 999_999_999
    }
    body = valid_enrolment.merge(
      email: "siti@example.com",
      place_name: "p" * 200,
      how_to_find: "h" * 2000,
      other_help: "o" * 500,
      family_phone: "0123456789",
      help: %w[food clothing school_supplies help_applying],
      members: [ member.merge(role: "head") ] + Array.new(19) { member }
    )
    assert_operator body.to_json.bytesize, :<=, LimitRequestBody::LIMIT

    assert_difference "FamilyMember.count", 20 do
      post "/enrolments", params: body, as: :json
    end

    assert_response :created
  end

  test "a body over 128 KiB returns 413 and saves nothing" do
    assert_no_difference [ "Enrolment.count", "FamilyUnit.count", "FamilyMember.count", "Locality.count" ] do
      post "/enrolments",
        params: "x" * (128 * 1024 + 1),
        headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :content_too_large
    error = response.parsed_body.fetch("error")
    assert_equal "PAYLOAD_TOO_LARGE", error["code"]
    assert_equal "Payload is too large", error["message"]
    assert_equal({}, error["details"])
  end

  test "a chunked body returns 413 and saves nothing" do
    assert_no_difference [ "Enrolment.count", "FamilyUnit.count", "FamilyMember.count", "Locality.count" ] do
      post "/enrolments",
        params: valid_enrolment,
        as: :json,
        env: { "HTTP_TRANSFER_ENCODING" => "chunked" }
    end

    assert_response :content_too_large
  end

  test "zero members returns 422 and saves nothing" do
    body = valid_enrolment
    body[:members] = []

    assert_rejected body, "Members are required", "members" => [ "are required" ]
  end

  test "two heads returns 422 and saves nothing" do
    body = valid_enrolment
    body[:members] = [
      { role: "head", name: "Siti", gender: "female" },
      { role: "head", name: "Aminah", gender: "male" }
    ]

    assert_rejected body, "Members have more than one head", "members" => [ "has more than one head" ]
  end

  test "a role outside head and member returns 422 and saves nothing" do
    body = valid_enrolment
    body[:members] = [
      { role: "head", name: "Siti", gender: "female" },
      { role: "other", name: "Ali", gender: "male" }
    ]

    assert_rejected body, "Member role is not included", "members" => [ "role is not included" ]
  end

  test "members with no head returns 422 and saves nothing" do
    body = valid_enrolment
    body[:members] = [
      { role: "member", name: "Ali", gender: "male" }
    ]

    assert_rejected body, "Members need one head", "members" => [ "needs one head" ]
  end

  test "a family phone that is not a phone returns 422 and saves nothing" do
    body = valid_enrolment
    body[:family_phone] = "Mary at the shop"

    assert_rejected body, "Family phone is not a phone number", "family_phone" => [ "is not a phone number" ]
  end

  test "an invalid email returns 422 and saves nothing" do
    body = valid_enrolment
    body[:email] = "not an email"

    assert_rejected body, "Email is invalid", "email" => [ "is invalid" ]
  end

  test "a valid email is stored and returned" do
    body = valid_enrolment
    body[:email] = "siti@example.com"

    post "/enrolments", params: body, as: :json

    assert_response :created
    assert_equal "siti@example.com", Enrolment.order(:created_at).last.email
    assert_equal "siti@example.com", response.parsed_body["email"]
  end

  test "a place name over 200 characters returns 422 and saves nothing" do
    body = valid_enrolment
    body[:place_name] = "a" * 201

    assert_rejected body, "Place name is too long", "place_name" => [ "is too long" ]
  end

  test "an age outside 0 through 130 returns 422 and saves nothing" do
    [ -1, 131 ].each do |age|
      body = valid_enrolment
      body[:members][0][:age] = age

      assert_rejected body, "Age is out of range", "members" => [ "age is out of range" ]
    end
  end

  test "ages 0 and 130 are stored" do
    [ 0, 130 ].each do |age|
      body = valid_enrolment
      body[:members][0][:age] = age

      post "/enrolments", params: body, as: :json

      assert_response :created
      assert_equal age, Enrolment.order(:created_at).last.members.sole.age
      assert_equal age, response.parsed_body["members"].sole["age"]
    end
  end

  test "a coordinate that is not a number returns 422 and saves nothing" do
    body = valid_enrolment
    body[:latitude] = "3.14"

    assert_rejected body, "Latitude is not a number", "latitude" => [ "is not a number" ]
  end

  test "text over its limit returns 422 and saves nothing" do
    too_long = {
      [ :how_to_find, "a" * 2001 ] => [ "How to find them is too long", { "how_to_find" => [ "is too long" ] } ],
      [ :other_help, "a" * 501 ] => [ "Other help is too long", { "other_help" => [ "is too long" ] } ],
      [ :email, "#{"a" * 250}@example.com" ] => [ "Email is too long", { "email" => [ "is too long" ] } ]
    }
    too_long.each do |(key, value), (message, details)|
      body = valid_enrolment
      body[key] = value
      assert_rejected body, message, details
    end

    described = valid_enrolment
    described[:members][0][:description] = "a" * 2001
    assert_rejected described, "Description is too long", "members" => [ "description is too long" ]

    named = valid_enrolment
    named[:members][0][:name] = "a" * 201
    assert_rejected named, "Head name is too long", "members" => [ "head name is too long" ]

    employed = valid_enrolment
    employed[:members][0][:working] = true
    employed[:members][0][:job] = "a" * 201
    assert_rejected employed, "Job is too long", "members" => [ "job is too long" ]

    paid = valid_enrolment
    paid[:members][0][:working] = true
    paid[:members][0][:monthly_amount] = 1_000_000_000
    assert_rejected paid, "Monthly amount is out of range", "members" => [ "monthly amount is out of range" ]
  end

  test "a coordinate outside its range returns 422 and saves nothing" do
    body = valid_enrolment
    body[:latitude] = 90.1

    assert_rejected body, "Latitude is out of range", "latitude" => [ "is out of range" ]
  end

  test "only one of latitude and longitude returns 422 and saves nothing" do
    latitude_only = valid_enrolment
    latitude_only.delete(:longitude)
    longitude_only = valid_enrolment
    longitude_only.delete(:latitude)

    assert_rejected latitude_only, "Latitude and longitude must both be present", "latitude" => [ "must be present with longitude" ]
    assert_rejected longitude_only, "Latitude and longitude must both be present", "latitude" => [ "must be present with longitude" ]
  end

  test "a sent amount is discarded when the member is not working" do
    body = valid_enrolment
    body[:members][0][:working] = false
    body[:members][0][:job] = "Tailor"
    body[:members][0][:monthly_amount] = "about 800"

    post "/enrolments", params: body, as: :json

    assert_response :created
    head = Enrolment.order(:created_at).last.members.sole
    assert_equal false, head.working
    assert_equal "", head.job
    assert_nil head.monthly_amount
  end

  test "a working member in education keeps the job and the amount" do
    body = valid_enrolment
    body[:members][0][:in_education] = true
    body[:members][0][:working] = true
    body[:members][0][:job] = " Tailor "
    body[:members][0][:monthly_amount] = 800

    post "/enrolments", params: body, as: :json

    assert_response :created
    head = Enrolment.order(:created_at).last.members.sole
    assert_equal true, head.in_education
    assert_equal true, head.working
    assert_equal "Tailor", head.job
    assert_equal 800, head.monthly_amount
    member = response.parsed_body["members"].sole
    assert_equal true, member["in_education"]
    assert_equal true, member["working"]
    assert_equal "Tailor", member["job"]
    assert_equal 800, member["monthly_amount"]
  end

  test "on behalf must be true or false" do
    missing = valid_enrolment
    missing.delete(:on_behalf)

    assert_rejected missing, "On behalf must be true or false", "on_behalf" => [ "must be true or false" ]

    as_string = valid_enrolment
    as_string[:on_behalf] = "false"

    assert_rejected as_string, "On behalf must be true or false", "on_behalf" => [ "must be true or false" ]
  end

  test "dots and parentheses are removed from a phone number" do
    body = valid_enrolment
    body[:enroler_contact] = "(012) 345.6789"

    post "/enrolments", params: body, as: :json

    assert_response :created
    assert_equal "0123456789", Enrolment.order(:created_at).last.enroler_contact
    assert_equal "0123456789", response.parsed_body["enroler_contact"]
  end

  test "coordinates are stored when the place name matches the nearest locality with a center" do
    locality = create_locality(name: "Straße Weg", latitude: 0, longitude: 0, radius_metres: 500, created_at: Time.utc(2026, 1, 1))

    assert_no_difference "Locality.count" do
      post "/enrolments", params: valid_enrolment.merge(place_name: "  strasse   weg ", latitude: 0, longitude: 0), as: :json
    end

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal locality.id, enrolment.locality_id
    assert_equal "strasse weg", enrolment.place_name
    assert_equal 0, enrolment.latitude
    assert_equal 0, enrolment.longitude
    assert_instance_of Float, response.parsed_body["latitude"]
    assert_instance_of Float, response.parsed_body["longitude"]
    assert_equal 0.0, response.parsed_body["latitude"]
    assert_equal 0.0, response.parsed_body["longitude"]
    locality.reload
    assert_equal "Straße Weg", locality.name
    assert_equal 0, locality.latitude
    assert_equal 500, locality.radius_metres
  end

  test "a different place name stores null coordinates and still saves" do
    circled = create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 5_000, created_at: Time.utc(2026, 1, 1))

    assert_difference [ "Enrolment.count", "Locality.count" ], 1 do
      post "/enrolments", params: valid_enrolment.merge(place_name: "Kampung Baru", latitude: 0, longitude: 0), as: :json
    end

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_nil enrolment.latitude
    assert_nil enrolment.longitude
    assert_nil response.parsed_body["latitude"]
    assert_nil response.parsed_body["longitude"]
    assert_not_equal circled.id, enrolment.locality_id
    created = enrolment.locality
    assert_equal "Kampung Baru", created.name
    assert_nil created.latitude
    assert_nil created.longitude
    assert_nil created.radius_metres
  end

  test "a name other than the nearest center stores null coordinates on the existing locality" do
    create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 1_000, created_at: Time.utc(2026, 1, 2))
    named = create_locality(name: "Kampung Baru", latitude: 0, longitude: 1, radius_metres: 1_000, created_at: Time.utc(2026, 1, 1))

    assert_no_difference "Locality.count" do
      post "/enrolments", params: valid_enrolment.merge(place_name: "Kampung Baru", latitude: 0, longitude: 0), as: :json
    end

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal named.id, enrolment.locality_id
    assert_nil enrolment.latitude
    assert_nil enrolment.longitude
    assert_nil response.parsed_body["latitude"]
    assert_nil response.parsed_body["longitude"]
  end

  test "a kept point inside several circles assigns the closest staffed locality" do
    closer = create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 5_000, created_at: Time.utc(2026, 1, 1))
    staffed = create_locality(name: "Staffed", latitude: 0, longitude: 0.02, radius_metres: 5_000, created_at: Time.utc(2026, 1, 2))
    LocalityAssignment.create!(account_id: SecureRandom.uuid, locality: staffed)

    post "/enrolments", params: valid_enrolment.merge(place_name: "Block 4", latitude: 0, longitude: 0), as: :json

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal staffed.id, enrolment.locality_id
    assert_not_equal closer.id, enrolment.locality_id
    assert_equal 0, enrolment.latitude
    assert_equal 0, enrolment.longitude
  end

  test "a kept point inside several circles assigns the closest locality when none are staffed" do
    farther = create_locality(name: "Block 4", latitude: 0, longitude: 1, radius_metres: 200_000, created_at: Time.utc(2026, 1, 1))
    nearer = create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 1_000, created_at: Time.utc(2026, 1, 2))

    post "/enrolments", params: valid_enrolment.merge(place_name: "Block 4", latitude: 0, longitude: 0), as: :json

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal nearer.id, enrolment.locality_id
    assert_not_equal farther.id, enrolment.locality_id
    assert_equal 0, enrolment.latitude
    assert_equal 0, enrolment.longitude
  end

  test "a kept point prefers a fitting locality with a center over one with no center" do
    name_only = create_locality(name: "Block 4", created_at: Time.utc(2026, 1, 1))
    circled = create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 1_000, created_at: Time.utc(2026, 1, 2))

    post "/enrolments", params: valid_enrolment.merge(place_name: "Block 4", latitude: 0, longitude: 0), as: :json

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal circled.id, enrolment.locality_id
    assert_not_equal name_only.id, enrolment.locality_id
    assert_equal 0, enrolment.latitude
    assert_equal 0, enrolment.longitude
  end

  test "equal distance uses the earliest created locality when the point is kept" do
    earlier = create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 1_000, created_at: Time.utc(2026, 1, 1))
    later = create_locality(name: "Other", latitude: 0, longitude: 0, radius_metres: 1_000, created_at: Time.utc(2026, 1, 2))

    post "/enrolments", params: valid_enrolment.merge(place_name: "Block 4", latitude: 0, longitude: 0), as: :json

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal earlier.id, enrolment.locality_id
    assert_not_equal later.id, enrolment.locality_id
    assert_equal 0, enrolment.latitude
    assert_equal 0, enrolment.longitude
    assert_equal 0.0, response.parsed_body["latitude"]
    assert_equal 0.0, response.parsed_body["longitude"]
  end

  test "duplicate help keys are stored once in first-seen order" do
    body = valid_enrolment
    body[:help] = [ "clothing", "food", "clothing", "school_supplies" ]

    post "/enrolments", params: body, as: :json

    assert_response :created
    assert_equal [ "clothing", "food", "school_supplies" ], Enrolment.order(:created_at).last.help
  end

  private
    def create_locality(name:, created_at:, latitude: nil, longitude: nil, radius_metres: nil)
      travel_to(created_at) do
        Locality.create!(name:, latitude:, longitude:, radius_metres:)
      end
    end

    def valid_enrolment
      {
        on_behalf: false,
        consent_text: "client sentence that must be ignored",
        enroler_contact: "+60 12-345 6789",
        place_name: "  Kampung   Baru ",
        family_phone: "",
        how_to_find: " ",
        help: [],
        other_help: "",
        latitude: -90,
        longitude: 180,
        members: [
          {
            role: "head",
            name: " Siti ",
            gender: "unspecified"
          }
        ]
      }
    end

    def assert_rejected(body, message, details)
      assert_no_difference [ "Enrolment.count", "FamilyUnit.count", "FamilyMember.count", "Locality.count" ] do
        post "/enrolments", params: body, as: :json
      end

      assert_response :unprocessable_content
      error = response.parsed_body.fetch("error")
      assert_equal [ "code", "details", "message" ], error.keys.sort
      assert_equal "VALIDATION_ERROR", error["code"]
      assert_equal message, error["message"]
      assert_equal details, error["details"]
    end

    def enrolment_json(enrolment)
      {
        "id" => enrolment.id,
        "submitted_at" => enrolment.submitted_at.utc.iso8601,
        "on_behalf" => enrolment.on_behalf,
        "consent_text" => enrolment.consent_text,
        "enroler_contact" => enrolment.enroler_contact,
        "email" => enrolment.email,
        "place_name" => enrolment.place_name,
        "latitude" => enrolment.latitude&.to_f,
        "longitude" => enrolment.longitude&.to_f,
        "family_phone" => enrolment.family_phone,
        "how_to_find" => enrolment.how_to_find,
        "help" => enrolment.help,
        "other_help" => enrolment.other_help,
        "locality" => { "id" => enrolment.locality.id, "name" => enrolment.locality.name },
        "members" => enrolment.members.map { |member|
          {
            "id" => member.id,
            "role" => member.role,
            "name" => member.name,
            "age" => member.age,
            "gender" => member.gender,
            "description" => member.description,
            "in_education" => member.in_education,
            "working" => member.working,
            "job" => member.job,
            "monthly_amount" => member.monthly_amount
          }
        },
        "progress" => { "case_in" => true, "looks" => [], "visit_at" => nil }
      }
    end
end
