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
end
