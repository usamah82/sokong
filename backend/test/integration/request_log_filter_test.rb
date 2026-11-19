require "test_helper"

class RequestLogFilterTest < ActiveSupport::TestCase
  test "enrolment personal fields are filtered from the request log" do
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(
      "email" => "siti@example.com",
      "enroler_contact" => "+60123456789",
      "family_phone" => "0123456789",
      "place_name" => "Kampung Baru",
      "how_to_find" => "blue door behind the shop",
      "other_help" => "rent",
      "latitude" => 3.139,
      "longitude" => 101.6869,
      "members" => [
        {
          "name" => "Siti",
          "description" => "needs food",
          "job" => "tailor",
          "monthly_amount" => 800,
          "gender" => "female"
        }
      ]
    )

    assert_equal "[FILTERED]", filtered["email"]
    assert_equal "[FILTERED]", filtered["enroler_contact"]
    assert_equal "[FILTERED]", filtered["family_phone"]
    assert_equal "[FILTERED]", filtered["place_name"]
    assert_equal "[FILTERED]", filtered["how_to_find"]
    assert_equal "[FILTERED]", filtered["other_help"]
    assert_equal "[FILTERED]", filtered["latitude"]
    assert_equal "[FILTERED]", filtered["longitude"]
    member = filtered["members"].sole
    assert_equal "[FILTERED]", member["name"]
    assert_equal "[FILTERED]", member["description"]
    assert_equal "[FILTERED]", member["job"]
    assert_equal "[FILTERED]", member["monthly_amount"]
    assert_equal "female", member["gender"]
  end

  test "interview answers are filtered and the stage choices stay visible" do
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(
      "stage" => "who_is_here",
      "bringing_basket" => false,
      "assigned_workers" => [ "Aman" ],
      "people" => [
        {
          "name" => "Siti",
          "phone" => "+60123456789",
          "birth_date" => "2024-02-29",
          "gender" => "female",
          "relationship" => "spouse",
          "identity" => "verified",
          "origin" => "Kedah",
          "working" => true,
          "in_school" => false,
          "previous_jobs" => "sewing",
          "wished_work" => "a shop",
          "skills" => "patterns",
          "school_going" => "well",
          "school_where" => "kampung",
          "school_travel" => "walk",
          "absent_since" => "2024-01-02",
          "absent_reason" => "Work",
          "documents" => [
            { "kind" => "national_id", "number" => "900101015555", "other_label" => "Village letter" }
          ]
        }
      ],
      "notes" => "They spoke quietly",
      "others_stay_detail" => "cousin",
      "care_for_parents_detail" => "Mother",
      "basket" => "rice",
      "how_it_started" => "married",
      "need_most" => "food",
      "hard_week" => "quiet",
      "who_steps_in" => "aunt",
      "children_at_home" => "two children",
      "unsafe_detail" => "the stairs",
      "good_family_unit_gap" => "the father is away",
      "basic_necessities_gap" => "rent is behind"
    )

    assert_equal "who_is_here", filtered["stage"]
    assert_equal false, filtered["bringing_basket"]
    assert_equal "[FILTERED]", filtered["assigned_workers"]
    assert_equal "[FILTERED]", filtered["notes"]
    assert_equal "[FILTERED]", filtered["others_stay_detail"]
    assert_equal "[FILTERED]", filtered["care_for_parents_detail"]
    assert_equal "[FILTERED]", filtered["basket"]
    assert_equal "[FILTERED]", filtered["how_it_started"]
    assert_equal "[FILTERED]", filtered["need_most"]
    assert_equal "[FILTERED]", filtered["hard_week"]
    assert_equal "[FILTERED]", filtered["who_steps_in"]
    assert_equal "[FILTERED]", filtered["children_at_home"]
    assert_equal "[FILTERED]", filtered["unsafe_detail"]
    assert_equal "[FILTERED]", filtered["good_family_unit_gap"]
    assert_equal "[FILTERED]", filtered["basic_necessities_gap"]
    person = filtered["people"].sole
    assert_equal "[FILTERED]", person["name"]
    assert_equal "[FILTERED]", person["phone"]
    assert_equal "[FILTERED]", person["birth_date"]
    assert_equal "[FILTERED]", person["origin"]
    assert_equal "[FILTERED]", person["absent_since"]
    assert_equal "[FILTERED]", person["absent_reason"]
    assert_equal "female", person["gender"]
    assert_equal "spouse", person["relationship"]
    assert_equal "verified", person["identity"]
    assert_equal true, person["working"]
    assert_equal false, person["in_school"]
    assert_equal "[FILTERED]", person["previous_jobs"]
    assert_equal "[FILTERED]", person["wished_work"]
    assert_equal "[FILTERED]", person["skills"]
    assert_equal "[FILTERED]", person["school_going"]
    assert_equal "[FILTERED]", person["school_where"]
    assert_equal "[FILTERED]", person["school_travel"]
    document = person["documents"].sole
    assert_equal "national_id", document["kind"]
    assert_equal "[FILTERED]", document["number"]
    assert_equal "[FILTERED]", document["other_label"]
  end
end
