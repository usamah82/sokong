require "test_helper"

class EnrolmentsTest < ActionDispatch::IntegrationTest
  SELF_CONSENT = "Submission means the family consents. That consent is confirmed at the verification visit."
  ON_BEHALF_CONSENT = "This case is valid and will be checked at a visit. It may not be enrolled unless the family consents then."

  test "a named head with empty optional fields returns the enrolment and a new locality" do
    post_enrolment valid_body

    assert_response :created
    assert_equal 1, Enrolment.count
    assert_equal 1, FamilyUnit.count
    assert_equal 1, FamilyMember.count
    assert_equal 1, Locality.count

    document = response.parsed_body
    enrolment = Enrolment.find(document.fetch("id"))
    locality = enrolment.locality

    assert_equal expected_keys, document.keys
    assert_equal 36, document["id"].length
    assert_equal enrolment.submitted_at.utc.iso8601, document["submitted_at"]
    assert_equal false, document["on_behalf"]
    assert_equal SELF_CONSENT, document["consent_text"]
    assert_equal "+60123456789", document["enroler_contact"]
    assert_equal "", document["email"]
    assert_equal "Kampung Baru", document["place_name"]
    assert_nil document["latitude"]
    assert_nil document["longitude"]
    assert_equal "", document["family_phone"]
    assert_equal "", document["how_to_find"]
    assert_equal [], document["help"]
    assert_equal "", document["other_help"]
    assert_equal({ "id" => locality.id, "name" => "Kampung Baru" }, document["locality"])
    assert_nil locality.latitude
    assert_nil locality.longitude
    assert_nil locality.radius_metres
    assert_equal [ head_document(enrolment.members.sole) ], document["members"]
    assert_equal({ "case_in" => true, "looks" => [], "visit_at" => nil }, document["progress"])
    assert_nil enrolment.visit_at
    assert_nil enrolment.latitude
    assert_nil enrolment.longitude
  end

  test "a second body creates another family and a matching place name reuses the locality" do
    existing = Locality.create!(name: "Block 4")

    post_enrolment valid_body(place_name: "  BLOCK   4 ", enroler_contact: "012-345 6789")

    assert_response :created
    first = response.parsed_body
    assert_equal "BLOCK 4", first["place_name"]
    assert_equal "0123456789", first["enroler_contact"]
    assert_equal existing.id, first.dig("locality", "id")
    assert_equal "Block 4", first.dig("locality", "name")
    assert_equal 1, Locality.count

    post_enrolment valid_body(
      on_behalf: true,
      consent_text: "client sentence",
      enroler_contact: "+60 (12) 987-6543",
      email: "  Siti@Example.com ",
      place_name: "block 4",
      members: [ head(name: "Aminah", gender: "female") ]
    )

    assert_response :created
    second = response.parsed_body
    assert_equal 2, Enrolment.count
    assert_equal 2, FamilyUnit.count
    assert_equal 1, Locality.count
    assert_not_equal first["id"], second["id"]
    assert_equal existing.id, second.dig("locality", "id")
    assert_equal true, second["on_behalf"]
    assert_equal ON_BEHALF_CONSENT, second["consent_text"]
    assert_equal "+60129876543", second["enroler_contact"]
    assert_equal "Siti@Example.com", second["email"]
    assert_equal [ "Aminah" ], second["members"].map { |member| member["name"] }
  end

  test "self enrolment stores the self consent sentence and ignores a client sentence" do
    post_enrolment valid_body(on_behalf: false, consent_text: "Not the spec sentence")

    assert_response :created
    assert_equal SELF_CONSENT, response.parsed_body["consent_text"]
    assert_equal false, response.parsed_body["on_behalf"]
  end

  test "a sent coordinate pair is stored as null" do
    post_enrolment valid_body(latitude: 3.14, longitude: 101.7)

    assert_response :created
    document = response.parsed_body
    enrolment = Enrolment.find(document.fetch("id"))

    assert_nil document["latitude"]
    assert_nil document["longitude"]
    assert_nil enrolment.latitude
    assert_nil enrolment.longitude
    assert_nil enrolment.locality.latitude
    assert_nil enrolment.locality.longitude
  end

  test "a formatted phone is stored as the remainder and an integer age and amount are kept" do
    post_enrolment valid_body(
      enroler_contact: "+60 12-345 6789",
      family_phone: "(012) 345.6789",
      help: [ "clothing", "food", "clothing" ],
      how_to_find: "  Blue door  ",
      other_help: "  rent ",
      members: [
        head(
          name: " Siti ",
          age: 40,
          gender: "female",
          description: "  Keeps this  ",
          in_education: true,
          working: true,
          job: " Sewing ",
          monthly_amount: 800
        )
      ]
    )

    assert_response :created
    document = response.parsed_body
    member = document["members"].sole

    assert_equal "+60123456789", document["enroler_contact"]
    assert_equal "0123456789", document["family_phone"]
    assert_equal [ "clothing", "food" ], document["help"]
    assert_equal "Blue door", document["how_to_find"]
    assert_equal "rent", document["other_help"]
    assert_equal "Siti", member["name"]
    assert_equal 40, member["age"]
    assert_equal "female", member["gender"]
    assert_equal "Keeps this", member["description"]
    assert_equal true, member["in_education"]
    assert_equal true, member["working"]
    assert_equal "Sewing", member["job"]
    assert_equal 800, member["monthly_amount"]
  end

  test "a member who is not working stores an empty job and a null amount" do
    post_enrolment valid_body(
      members: [
        head(working: false, job: "Tailor", monthly_amount: "about 800", in_education: true, description: "Keeps this")
      ]
    )

    assert_response :created
    member = response.parsed_body["members"].sole

    assert_equal true, member["in_education"]
    assert_equal false, member["working"]
    assert_equal "Keeps this", member["description"]
    assert_equal "", member["job"]
    assert_nil member["monthly_amount"]
  end

  test "missing enroler phone returns validation error and saves nothing" do
    error = assert_rejected(valid_body(enroler_contact: "  "))

    assert_equal "Enroler contact is required", error["message"]
    assert_equal({ "enroler_contact" => [ "is required" ] }, error["details"])
  end

  test "a contact that is not a phone returns validation error and saves nothing" do
    [ "Mary at the shop", "123", "phone: 0123456789" ].each do |contact|
      error = assert_rejected(valid_body(enroler_contact: contact))

      assert_equal "Enroler contact is not a phone number", error["message"]
      assert_equal({ "enroler_contact" => [ "is not a phone number" ] }, error["details"])
    end
  end

  test "a family phone that is not a phone returns validation error and saves nothing" do
    error = assert_rejected(valid_body(family_phone: "Mary at the shop"))

    assert_equal "Family phone is not a phone number", error["message"]
    assert_equal({ "family_phone" => [ "is not a phone number" ] }, error["details"])
  end

  test "a missing place name returns validation error and saves nothing" do
    error = assert_rejected(valid_body(place_name: "   "))

    assert_equal "Place name is required", error["message"]
    assert_equal({ "place_name" => [ "is required" ] }, error["details"])
  end

  test "a place name over 200 characters returns validation error and saves nothing" do
    error = assert_rejected(valid_body(place_name: "a" * 201))

    assert_equal "Place name is too long", error["message"]
    assert_equal({ "place_name" => [ "is too long" ] }, error["details"])
  end

  test "an invalid email returns validation error and saves nothing" do
    error = assert_rejected(valid_body(email: "not-an-email"))

    assert_equal "Email is invalid", error["message"]
    assert_equal({ "email" => [ "is invalid" ] }, error["details"])
  end

  test "an email over 254 characters returns validation error and saves nothing" do
    error = assert_rejected(valid_body(email: "#{'a' * 243}@example.com"))

    assert_equal "Email is too long", error["message"]
    assert_equal({ "email" => [ "is too long" ] }, error["details"])
  end

  test "a missing head name returns validation error and saves nothing" do
    error = assert_rejected(valid_body(members: [ head(name: "  ") ]))

    assert_equal "Head name is required", error["message"]
    assert_equal({ "name" => [ "is required" ] }, error["details"])
  end

  test "a gender outside the three values returns validation error and saves nothing" do
    error = assert_rejected(valid_body(members: [ head(gender: "other") ]))

    assert_equal "Gender is invalid", error["message"]
    assert_equal({ "gender" => [ "is invalid" ] }, error["details"])
  end

  test "a non-integer age returns validation error and saves nothing" do
    [ 8.5, "8" ].each do |age|
      error = assert_rejected(valid_body(members: [ head(age: age) ]))

      assert_equal "Age is not an integer", error["message"]
      assert_equal({ "age" => [ "is not an integer" ] }, error["details"])
    end
  end

  test "an age outside 0 through 130 returns validation error and saves nothing" do
    error = assert_rejected(valid_body(members: [ head(age: 131) ]))

    assert_equal "Age is out of range", error["message"]
    assert_equal({ "age" => [ "is out of range" ] }, error["details"])
  end

  test "a non-integer monthly amount returns validation error and saves nothing" do
    [ "about 800", 800.5 ].each do |amount|
      error = assert_rejected(valid_body(members: [ head(working: true, monthly_amount: amount) ]))

      assert_equal "Monthly amount is not an integer", error["message"]
      assert_equal({ "monthly_amount" => [ "is not an integer" ] }, error["details"])
    end
  end

  test "a help key outside the four returns validation error and saves nothing" do
    error = assert_rejected(valid_body(help: [ "food", "shelter" ]))

    assert_equal "Help is invalid", error["message"]
    assert_equal({ "help" => [ "is invalid" ] }, error["details"])
  end

  test "zero members returns validation error and saves nothing" do
    error = assert_rejected(valid_body(members: []))

    assert_equal "Members are required", error["message"]
    assert_equal({ "members" => [ "are required" ] }, error["details"])
  end

  test "two heads returns validation error and saves nothing" do
    error = assert_rejected(valid_body(members: [ head(name: "Siti"), head(name: "Aminah") ]))

    assert_equal "A family has one head", error["message"]
    assert_equal({ "members" => [ "has more than one head" ] }, error["details"])
  end

  test "only one of latitude and longitude returns validation error and saves nothing" do
    missing_longitude = assert_rejected(valid_body(latitude: 3.1))
    assert_equal "Longitude is required", missing_longitude["message"]
    assert_equal({ "longitude" => [ "is required" ] }, missing_longitude["details"])

    missing_latitude = assert_rejected(valid_body(longitude: 101.7))
    assert_equal "Latitude is required", missing_latitude["message"]
    assert_equal({ "latitude" => [ "is required" ] }, missing_latitude["details"])
  end

  test "a coordinate outside its range returns validation error and saves nothing" do
    error = assert_rejected(valid_body(latitude: 91, longitude: 0))

    assert_equal "Latitude is out of range", error["message"]
    assert_equal({ "latitude" => [ "is out of range" ] }, error["details"])
  end

  test "how to find them over 2000 characters returns validation error and saves nothing" do
    error = assert_rejected(valid_body(how_to_find: "a" * 2001))

    assert_equal "How to find them is too long", error["message"]
    assert_equal({ "how_to_find" => [ "is too long" ] }, error["details"])
  end

  test "other help over 500 characters returns validation error and saves nothing" do
    error = assert_rejected(valid_body(other_help: "a" * 501))

    assert_equal "Other help is too long", error["message"]
    assert_equal({ "other_help" => [ "is too long" ] }, error["details"])
  end

  private
    def post_enrolment(body)
      post "/enrolments", params: body, as: :json
    end

    def assert_rejected(body)
      assert_no_difference [ "Enrolment.count", "FamilyUnit.count", "FamilyMember.count", "Locality.count" ] do
        post_enrolment body
      end
      assert_response :unprocessable_entity
      error = response.parsed_body.fetch("error")
      assert_equal "VALIDATION_ERROR", error["code"]
      assert_equal [ "code", "message", "details" ], error.keys
      error
    end

    def expected_keys
      %w[
        id submitted_at on_behalf consent_text enroler_contact email place_name
        latitude longitude family_phone how_to_find help other_help locality members progress
      ]
    end

    def head_document(member)
      {
        "id" => member.id,
        "role" => "head",
        "name" => "Siti",
        "age" => nil,
        "gender" => "unspecified",
        "description" => "",
        "in_education" => false,
        "working" => false,
        "job" => "",
        "monthly_amount" => nil
      }
    end

    def valid_body(**overrides)
      {
        on_behalf: false,
        consent_text: "client sentence",
        enroler_contact: "+60 12-345 6789",
        email: nil,
        place_name: "Kampung Baru",
        family_phone: nil,
        how_to_find: nil,
        help: nil,
        other_help: nil,
        members: [ head ]
      }.deep_merge(overrides)
    end

    def head(**overrides)
      {
        role: "head",
        name: "Siti",
        age: nil,
        gender: "unspecified",
        description: nil,
        in_education: false,
        working: false,
        job: nil,
        monthly_amount: nil
      }.merge(overrides)
    end
end
