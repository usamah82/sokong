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
    link_account(staffed)

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

  test "a matching center with no radius keeps the point" do
    locality = create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: nil, created_at: Time.utc(2026, 1, 1))

    assert_no_difference "Locality.count" do
      post "/enrolments", params: valid_enrolment.merge(place_name: "Block 4", latitude: 0, longitude: 0), as: :json
    end

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal locality.id, enrolment.locality_id
    assert_equal 0, enrolment.latitude
    assert_equal 0, enrolment.longitude
    assert_instance_of Float, response.parsed_body["latitude"]
    assert_instance_of Float, response.parsed_body["longitude"]
    assert_equal 0.0, response.parsed_body["latitude"]
    assert_equal 0.0, response.parsed_body["longitude"]
    locality.reload
    assert_nil locality.radius_metres
  end

  test "a matching name keeps a point outside that circle and assigns the staffed circle that covers it" do
    named = create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 10, created_at: Time.utc(2026, 1, 1))
    staffed = create_locality(name: "Other", latitude: 0, longitude: 1, radius_metres: 200_000, created_at: Time.utc(2026, 1, 2))
    link_account(staffed)

    post "/enrolments", params: valid_enrolment.merge(place_name: "Block 4", latitude: 0, longitude: 0.25), as: :json

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal staffed.id, enrolment.locality_id
    assert_not_equal named.id, enrolment.locality_id
    assert_equal 0, enrolment.latitude
    assert_equal 0.25, enrolment.longitude
    assert_instance_of Float, response.parsed_body["latitude"]
    assert_instance_of Float, response.parsed_body["longitude"]
    assert_equal 0.0, response.parsed_body["latitude"]
    assert_equal 0.25, response.parsed_body["longitude"]
  end

  test "the later name in an equal-distance tie stores null coordinates and is assigned by that name" do
    earlier = create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 1_000, created_at: Time.utc(2026, 1, 1))
    later = create_locality(name: "Kampung Baru", latitude: 0, longitude: 0, radius_metres: 1_000, created_at: Time.utc(2026, 1, 2))

    assert_no_difference "Locality.count" do
      post "/enrolments", params: valid_enrolment.merge(place_name: "Kampung Baru", latitude: 0, longitude: 0), as: :json
    end

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal later.id, enrolment.locality_id
    assert_not_equal earlier.id, enrolment.locality_id
    assert_nil enrolment.latitude
    assert_nil enrolment.longitude
    assert_nil response.parsed_body["latitude"]
    assert_nil response.parsed_body["longitude"]
  end

  test "a fractional kept coordinate is a JSON number" do
    create_locality(name: "Block 4", latitude: 3.25, longitude: 101.5, radius_metres: 500, created_at: Time.utc(2026, 1, 1))

    post "/enrolments", params: valid_enrolment.merge(place_name: "Block 4", latitude: 3.25, longitude: 101.5), as: :json

    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal 3.25, enrolment.latitude
    assert_equal 101.5, enrolment.longitude
    assert_instance_of Float, response.parsed_body["latitude"]
    assert_instance_of Float, response.parsed_body["longitude"]
    assert_equal 3.25, response.parsed_body["latitude"]
    assert_equal 101.5, response.parsed_body["longitude"]
  end

  test "duplicate help keys are stored once in first-seen order" do
    body = valid_enrolment
    body[:help] = [ "clothing", "food", "clothing", "school_supplies" ]

    post "/enrolments", params: body, as: :json

    assert_response :created
    assert_equal [ "clothing", "food", "school_supplies" ], Enrolment.order(:created_at).last.help
  end

  test "an email enqueues one invitation with the spec subject and body" do
    previous_logger = ActiveJob::Base.logger
    previous_mail_logger = ActionMailer::Base.logger
    assert_instance_of ActiveJob::QueueAdapters::TestAdapter, ActiveJob::Base.queue_adapter

    body = valid_enrolment.merge(
      email: "siti@example.com",
      place_name: "Kampung Baru",
      family_phone: "+60123456789",
      how_to_find: "the blue gate",
      help: [ "food" ],
      other_help: "school fees",
      members: [ { role: "head", name: "Siti Aminah", gender: "female" } ]
    )

    io = StringIO.new
    mail_log = StringIO.new
    ActiveJob::Base.logger = ActiveSupport::Logger.new(io)
    ActionMailer::Base.logger = ActiveSupport::Logger.new(mail_log)

    assert_enqueued_emails 1 do
      post "/enrolments", params: body, as: :json
    end

    assert_response :created
    assert_enqueued_email_with EnrolmentMailer, :invitation, args: [ "siti@example.com" ]

    perform_enqueued_jobs
    assert_not_includes io.string, "siti@example.com"
    assert_not_includes mail_log.string, "siti@example.com"
    mail = ActionMailer::Base.deliveries.sole
    assert_equal [ "siti@example.com" ], mail.to
    assert_equal "Sokong enrolment", mail.subject
    assert_equal INVITATION_BODY, mail.text_part&.body&.to_s&.strip || mail.body.to_s.strip
    assert_not_includes mail.body.to_s, "Siti Aminah"
    assert_not_includes mail.body.to_s, "Kampung Baru"
    assert_not_includes mail.body.to_s, "+60123456789"
    assert_not_includes mail.body.to_s, "blue gate"
    assert_not_includes mail.body.to_s, "food"
    assert_not_includes mail.body.to_s, "school fees"
  ensure
    ActiveJob::Base.logger = previous_logger
    ActionMailer::Base.logger = previous_mail_logger
  end

  test "a blank email enqueues no invitation" do
    assert_no_enqueued_emails do
      post "/enrolments", params: valid_enrolment, as: :json
    end
    assert_response :created

    assert_no_enqueued_emails do
      post "/enrolments", params: valid_enrolment.merge(email: "   "), as: :json
    end
    assert_response :created
  end

  test "a raised enqueue error still saves the enrolment and returns 201" do
    previous = ActiveJob::Base.queue_adapter
    adapter = RaisingQueueAdapter.new
    ActiveJob::Base.queue_adapter = adapter
    body = valid_enrolment.merge(email: "siti@example.com")

    assert_difference "Enrolment.count", 1 do
      post "/enrolments", params: body, as: :json
    end

    assert_equal 1, adapter.attempts
    assert_response :created
    assert_equal "siti@example.com", Enrolment.order(:created_at).last.email
  ensure
    ActiveJob::Base.queue_adapter = previous
  end

  test "a matching submitter reads their cases newest first and no one else's" do
    older = submit_enrolment(email: "SITI@example.com", name: "Siti")
    newer = submit_enrolment(email: "siti@example.com", name: "Aminah")
    other = submit_enrolment(email: "other@example.com", name: "Rahim")
    older.update!(submitted_at: 2.hours.ago)
    newer.update!(submitted_at: 1.hour.ago)

    token = confirmed_token(email: "  Siti@Example.com ")
    assert_no_enqueued_jobs do
      assert_no_difference -> { look_count } do
        get "/enrolments", headers: bearer(token)
      end
    end

    assert_response :ok
    assert_equal [ enrolment_json(newer.reload), enrolment_json(older.reload) ], response.parsed_body
    assert_empty response.parsed_body.first.dig("progress", "looks")
    assert_nil response.parsed_body.first.dig("progress", "visit_at")
    assert_not_includes response.parsed_body.map { |row| row["id"] }, other.id

    assert_no_enqueued_jobs do
      assert_no_difference -> { look_count } do
        get "/enrolments/#{newer.id}", headers: bearer(token)
      end
    end
    assert_response :ok
    assert_equal enrolment_json(newer.reload), response.parsed_body

    get "/enrolments/#{other.id}", headers: bearer(token)
    assert_not_found
    get "/enrolments/#{SecureRandom.uuid}", headers: bearer(token)
    assert_not_found

    other_token = confirmed_token(email: "Other@Example.com")
    get "/enrolments", headers: bearer(other_token)
    assert_response :ok
    assert_equal [ other.id ], response.parsed_body.map { |row| row["id"] }
    get "/enrolments/#{newer.id}", headers: bearer(other_token)
    assert_not_found
  end

  test "enrolment reads without a token are rejected" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")

    get "/enrolments"
    assert_sign_in_required
    get "/enrolments/#{enrolment.id}"
    assert_sign_in_required

    post "/accounts", params: {
      email: "siti@example.com",
      password: "correct horse battery staple",
      password_confirmation: "correct horse battery staple"
    }, as: :json
    assert_response :created
    post "/sessions", params: { email: "siti@example.com", password: "correct horse battery staple" }, as: :json
    assert_response :unauthorized
    assert_equal 0, AuthToken.count
    get "/enrolments"
    assert_sign_in_required
  end

  test "a linked worker lists a summary and the first detail records one empty look" do
    older = submit_enrolment(email: "siti@example.com", name: "Siti")
    newer = submit_enrolment(email: "aminah@example.com", name: "Aminah")
    older.update!(submitted_at: 2.hours.ago)
    newer.update!(submitted_at: 1.hour.ago)
    other = submit_enrolment(email: "rahim@example.com", name: "Rahim")
    other.update!(locality: create_locality(name: "Other Block", created_at: Time.current))

    token = worker_token(name: "Aman", locality: newer.locality)
    assert_no_enqueued_jobs do
      assert_no_difference "Look.count" do
        get "/enrolments", headers: bearer(token)
      end
    end

    assert_response :ok
    assert_equal [ worker_summary(newer.reload), worker_summary(older.reload) ], response.parsed_body

    assert_no_enqueued_jobs do
      assert_difference "Look.count", 1 do
        get "/enrolments/#{newer.id}", headers: bearer(token)
      end
    end
    assert_response :ok
    look = Look.order(:created_at).last
    assert_equal "Aman", look.worker_name
    assert_equal "", look.note
    assert_equal newer.id, look.enrolment_id
    assert_equal worker_detail(newer.reload, [ look ]), response.parsed_body
    assert_nil response.parsed_body["visit_at"]

    assert_no_enqueued_jobs do
      assert_no_difference "Look.count" do
        get "/enrolments/#{newer.id}", headers: bearer(token)
      end
    end
    assert_response :ok
    assert_equal worker_detail(newer.reload, [ look ]), response.parsed_body

    stranger = worker_token(name: "Farid", locality: other.locality)
    get "/enrolments/#{newer.id}", headers: bearer(stranger)
    assert_not_found
    assert_equal 1, Look.count

    unlinked = worker_token(name: "Noor")
    get "/enrolments", headers: bearer(unlinked)
    assert_response :ok
    assert_equal [], response.parsed_body

    submitter = confirmed_token(email: "siti@example.com")
    assert_no_difference "Look.count" do
      get "/enrolments/#{newer.id}", headers: bearer(submitter)
    end
    assert_not_found
  end

  test "a linked worker appends a note and the submitter sees looks in time order" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
    token = worker_token(name: "Aman", locality: enrolment.locality)
    get "/enrolments/#{enrolment.id}", headers: bearer(token)
    assert_response :ok
    empty = Look.order(:created_at).last

    assert_no_enqueued_jobs do
      assert_difference "Look.count", 1 do
        post "/enrolments/#{enrolment.id}/looks",
          params: { note: "Called the enroler, no answer" },
          headers: bearer(token),
          as: :json
      end
    end
    assert_response :created
    note = Look.order(:created_at).last
    assert_equal(
      {
        "id" => note.id,
        "worker_name" => "Aman",
        "looked_at" => note.looked_at.utc.iso8601,
        "note" => "Called the enroler, no answer"
      },
      response.parsed_body
    )

    assert_no_difference "Look.count" do
      post "/enrolments/#{enrolment.id}/looks", params: { note: "   " }, headers: bearer(token), as: :json
      assert_response :unprocessable_content
      assert_equal "Note is required", response.parsed_body.dig("error", "message")
      post "/enrolments/#{enrolment.id}/looks", params: { note: "a" * 2001 }, headers: bearer(token), as: :json
      assert_response :unprocessable_content
      assert_equal "Note is too long", response.parsed_body.dig("error", "message")
    end

    post "/enrolments/#{enrolment.id}/looks", params: { note: "a" * 2000 }, headers: bearer(token), as: :json
    assert_response :created

    stranger = worker_token(name: "Farid", locality: create_locality(name: "Other Block", created_at: Time.current))
    post "/enrolments/#{enrolment.id}/looks", params: { note: "Nope" }, headers: bearer(stranger), as: :json
    assert_not_found

    submitter = confirmed_token(email: "siti@example.com")
    assert_no_enqueued_jobs do
      post "/enrolments/#{enrolment.id}/looks", params: { note: "Nope" }, headers: bearer(submitter), as: :json
    end
    assert_not_found

    get "/enrolments/#{enrolment.id}", headers: bearer(submitter)
    assert_response :ok
    body = response.parsed_body
    assert_nil body.dig("progress", "visit_at")
    assert_equal [ empty.note, "Called the enroler, no answer", "a" * 2000 ], body.dig("progress", "looks").map { |look| look["note"] }
    assert_equal [ "Aman", "Aman", "Aman" ], body.dig("progress", "looks").map { |look| look["worker_name"] }
    times = body.dig("progress", "looks").map { |look| look["looked_at"] }
    assert_equal times.sort, times
  end

  INVITATION_BODY = "An enrolment was received. Sign up with this email address to see whether anyone has looked and whether a visit is set."

  class RaisingQueueAdapter
    attr_reader :attempts

    def initialize
      @attempts = 0
    end

    def enqueue(*)
      @attempts += 1
      raise "queue down"
    end

    def enqueue_at(*)
      raise "queue down"
    end
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

    def submit_enrolment(email:, name:)
      post "/enrolments", params: valid_enrolment.merge(
        email: email,
        members: [ { role: "head", name: name, gender: "unspecified" } ]
      ), as: :json
      assert_response :created
      Enrolment.order(:created_at).last
    end

    def confirmed_token(email:)
      password = "correct horse battery staple"
      post "/accounts", params: {
        email: email,
        password: password,
        password_confirmation: password
      }, as: :json
      assert_response :created
      perform_enqueued_jobs
      raw = ActionMailer::Base.deliveries.last.body.to_s[/token=([^&\s]+)/, 1]
      post "/account_verifications", params: { token: raw }, as: :json
      assert_response :no_content
      post "/sessions", params: { email: email, password: password }, as: :json
      assert_response :ok
      response.parsed_body.fetch("token")
    end

    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def assert_sign_in_required
      assert_response :unauthorized
      assert_equal "UNAUTHENTICATED", response.parsed_body.dig("error", "code")
      assert_equal "Sign in is required", response.parsed_body.dig("error", "message")
    end

    def assert_not_found
      assert_response :not_found
      error = response.parsed_body.fetch("error")
      assert_equal [ "code", "message" ], error.keys.sort
      assert_equal "NOT_FOUND", error["code"]
      assert_equal "Not found", error["message"]
      assert_not error.key?("details")
    end

    def worker_token(name:, locality: nil)
      account = Account.create!(
        email: "worker-#{SecureRandom.hex(4)}@example.com",
        password: "correct horse battery staple",
        role: "worker",
        name: name,
        email_confirmed_at: Time.current
      )
      LocalityAssignment.create!(account:, locality:) if locality
      post "/sessions", params: { email: account.email, password: "correct horse battery staple" }, as: :json
      assert_response :ok
      response.parsed_body.fetch("token")
    end

    def worker_summary(enrolment)
      {
        "id" => enrolment.id,
        "submitted_at" => enrolment.submitted_at.utc.iso8601,
        "place_name" => enrolment.place_name,
        "head_name" => enrolment.members.find { |member| member.role == "head" }.name,
        "enroler_contact" => enrolment.enroler_contact,
        "on_behalf" => enrolment.on_behalf,
        "locality" => { "id" => enrolment.locality.id, "name" => enrolment.locality.name }
      }
    end

    def worker_detail(enrolment, looks)
      worker_summary(enrolment).merge(
        "email" => enrolment.email,
        "how_to_find" => enrolment.how_to_find,
        "family_phone" => enrolment.family_phone,
        "help" => enrolment.help,
        "other_help" => enrolment.other_help,
        "consent_text" => enrolment.consent_text,
        "latitude" => enrolment.latitude&.to_f,
        "longitude" => enrolment.longitude&.to_f,
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
        "looks" => looks.map { |look|
          {
            "id" => look.id,
            "worker_name" => look.worker_name,
            "looked_at" => look.looked_at.utc.iso8601,
            "note" => look.note
          }
        },
        "visit_at" => nil
      )
    end

    def look_count
      return 0 unless Enrolment.connection.data_source_exists?("looks")

      Enrolment.connection.select_value("SELECT COUNT(*) FROM looks").to_i
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
