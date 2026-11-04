require "test_helper"

class EnrolmentTest < ActiveSupport::TestCase
  SELF_CONSENT = "Submission means the family consents. That consent is confirmed at the verification visit."

  test "one call creates a family and an enrolment, and a second call creates another pair" do
    enrolment = Enrolment.record!(
      on_behalf: false,
      consent_text: SELF_CONSENT,
      enroler_contact: "+60123456789",
      email: nil,
      place_name: "Kampung Baru",
      family_phone: nil,
      how_to_find: " ",
      help: nil,
      other_help: "",
      members: [
        {
          role: "member",
          name: "Ali",
          age: 0,
          gender: "male",
          description: "Younger",
          in_education: true,
          working: true,
          job: "none",
          monthly_amount: 0
        },
        {
          role: "head",
          name: "Siti",
          age: nil,
          gender: "unspecified",
          description: nil,
          in_education: false,
          working: true,
          job: nil,
          monthly_amount: ""
        }
      ]
    )

    assert_equal 1, Enrolment.count
    assert_equal 1, FamilyUnit.count
    assert_equal 2, FamilyMember.count
    assert_equal 36, enrolment.id.length
    assert_equal 36, enrolment.family_unit.id.length
    assert_equal [ "head", "member" ], enrolment.members.map(&:role)
    assert_equal [ "Siti", "Ali" ], enrolment.members.map(&:name)
    assert_equal [ 0, 1 ], enrolment.members.map(&:position)
    assert_nil enrolment.visit_at
    assert_not_nil enrolment.submitted_at
    assert_equal false, enrolment.on_behalf
    assert_equal SELF_CONSENT, enrolment.consent_text
    assert_equal "+60123456789", enrolment.enroler_contact
    assert_equal "", enrolment.email
    assert_equal "Kampung Baru", enrolment.place_name
    assert_nil enrolment.latitude
    assert_nil enrolment.longitude
    assert_equal "", enrolment.family_phone
    assert_equal "", enrolment.how_to_find
    assert_equal [], enrolment.help
    assert_equal "", enrolment.other_help
    assert_equal "Kampung Baru", enrolment.locality.name
    assert_nil enrolment.locality.latitude
    assert_nil enrolment.locality.longitude
    assert_nil enrolment.locality.radius_metres

    head = enrolment.members.first
    assert_equal 36, head.id.length
    assert_nil head.age
    assert_equal "", head.description
    assert_equal false, head.in_education
    assert_equal true, head.working
    assert_equal "", head.job
    assert_nil head.monthly_amount

    child = enrolment.members.second
    assert_equal 0, child.age
    assert_equal "Younger", child.description
    assert_equal true, child.in_education
    assert_equal "none", child.job
    assert_equal 0, child.monthly_amount

    second = Enrolment.record!(
      on_behalf: true,
      consent_text: "This case is valid and will be checked at a visit. It may not be enrolled unless the family consents then.",
      enroler_contact: "+60129876543",
      place_name: "Other Place",
      members: [
        {
          role: "head",
          name: "Aminah",
          age: 30,
          gender: "female",
          description: "",
          in_education: false,
          working: false,
          job: "",
          monthly_amount: nil
        }
      ]
    )

    assert_equal 2, Enrolment.count
    assert_equal 2, FamilyUnit.count
    assert_equal 2, Locality.count
    assert_not_equal enrolment.family_unit_id, second.family_unit_id
    assert_not_equal enrolment.locality_id, second.locality_id
    assert_nil second.visit_at
    assert_equal [ "Aminah" ], second.members.map(&:name)
    assert_equal [ "Siti", "Ali" ], enrolment.reload.members.map(&:name)
  end

  test "a member who is not working stores an empty job and a null amount" do
    enrolment = Enrolment.record!(
      on_behalf: false,
      consent_text: SELF_CONSENT,
      enroler_contact: "+60123456789",
      place_name: "Kampung Baru",
      members: [
        {
          role: "head",
          name: "Siti",
          age: 40,
          gender: "female",
          description: "Keeps this",
          in_education: true,
          working: false,
          job: "Tailor",
          monthly_amount: 800
        }
      ]
    )

    head = enrolment.members.sole

    assert_equal true, head.in_education
    assert_equal false, head.working
    assert_equal "Keeps this", head.description
    assert_equal "", head.job
    assert_nil head.monthly_amount
  end

  test "help keys are stored once in first-seen order" do
    enrolment = Enrolment.record!(
      on_behalf: false,
      consent_text: SELF_CONSENT,
      enroler_contact: "+60123456789",
      place_name: "Kampung Baru",
      help: [ "clothing", "food", "clothing", "school_supplies", "food" ],
      members: [
        {
          role: "head",
          name: "Siti",
          gender: "unspecified",
          working: false
        }
      ]
    )

    assert_equal [ "clothing", "food", "school_supplies" ], enrolment.reload.help
  end

  test "editing the locality afterward leaves the enrolment locality id unchanged" do
    locality = Locality.create!(name: "Block 4", latitude: 1.5, longitude: 101.5, radius_metres: 400)
    enrolment = Enrolment.record!(
      on_behalf: false,
      consent_text: SELF_CONSENT,
      enroler_contact: "+60123456789",
      place_name: "Block 4",
      members: [
        {
          role: "head",
          name: "Siti",
          gender: "female",
          working: true,
          job: "Sewing",
          monthly_amount: 800
        }
      ]
    )

    assert_equal locality.id, enrolment.locality_id
    assert_equal 1, Locality.count

    locality.update!(name: "Block 4 West", latitude: 2, longitude: 102, radius_metres: 800)

    assert_equal locality.id, enrolment.reload.locality_id
    assert_equal "Block 4", enrolment.place_name
  end

  test "a given point is stored and used when claiming the locality" do
    circled = Locality.create!(name: "Circle", latitude: 0, longitude: 0, radius_metres: 1_000)

    enrolment = Enrolment.record!(
      on_behalf: false,
      consent_text: SELF_CONSENT,
      enroler_contact: "+60123456789",
      place_name: "Somewhere else",
      latitude: 0,
      longitude: 0,
      members: [
        {
          role: "head",
          name: "Siti",
          gender: "female",
          working: false
        }
      ]
    )

    assert_equal circled.id, enrolment.locality_id
    assert_equal 1, Locality.count
    assert_equal 0, enrolment.latitude.to_f
    assert_equal 0, enrolment.longitude.to_f
  end
end
