require "test_helper"

class LocalitiesSuggestionTest < ActionDispatch::IntegrationTest
  test "no locality with a center returns null and writes nothing" do
    create_locality(name: "Name only", created_at: Time.utc(2026, 1, 1))
    create_locality(name: "Latitude only", latitude: 0, longitude: nil, created_at: Time.utc(2026, 1, 2))

    assert_no_difference [ "Locality.count", "Enrolment.count", "LocalityAssignment.count" ] do
      get "/localities/suggestion", params: { latitude: "-90", longitude: "180" }
    end

    assert_response :ok
    assert_equal({ "locality" => nil }, response.parsed_body)
  end

  test "a longitude without a latitude is not a center" do
    create_locality(name: "Longitude only", latitude: nil, longitude: 0, created_at: Time.utc(2026, 1, 1))

    assert_no_difference [ "Locality.count", "Enrolment.count", "LocalityAssignment.count" ] do
      get "/localities/suggestion", params: { latitude: "0", longitude: "0" }
    end

    assert_response :ok
    assert_equal({ "locality" => nil }, response.parsed_body)
  end

  test "the response is only the nearest locality name" do
    create_locality(name: "Farther", latitude: 0, longitude: 1, radius_metres: 200_000, created_at: Time.utc(2026, 1, 1))
    nearest = create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 1_000, created_at: Time.utc(2026, 1, 2))
    link_account(nearest)

    assert_no_difference [ "Locality.count", "Enrolment.count", "LocalityAssignment.count" ] do
      get "/localities/suggestion", params: { latitude: "0", longitude: "0" }
    end

    assert_response :ok
    assert_equal({ "locality" => { "name" => "Block 4" } }, response.parsed_body)
  end

  test "an unstaffed nearer center wins over a staffed farther center" do
    create_locality(name: "Block 4", latitude: 0, longitude: 0, radius_metres: 1_000, created_at: Time.utc(2026, 1, 2))
    farther = create_locality(name: "Farther", latitude: 0, longitude: 1, radius_metres: 200_000, created_at: Time.utc(2026, 1, 1))
    link_account(farther)

    assert_no_difference [ "Locality.count", "Enrolment.count", "LocalityAssignment.count" ] do
      get "/localities/suggestion", params: { latitude: "0", longitude: "0" }
    end

    assert_response :ok
    assert_equal({ "locality" => { "name" => "Block 4" } }, response.parsed_body)
  end

  test "a center with no radius is still the suggestion and there is no distance cutoff" do
    create_locality(name: "Name only", created_at: Time.utc(2026, 1, 1))
    create_locality(name: "Distant", latitude: 45, longitude: 90, radius_metres: nil, created_at: Time.utc(2026, 1, 2))

    get "/localities/suggestion", params: { latitude: "0", longitude: "0" }

    assert_response :ok
    assert_equal({ "locality" => { "name" => "Distant" } }, response.parsed_body)
  end

  test "an equal distance returns the earliest created locality" do
    create_locality(name: "Earlier", latitude: 0, longitude: 0, created_at: Time.utc(2026, 1, 1))
    create_locality(name: "Later", latitude: 0, longitude: 0, created_at: Time.utc(2026, 1, 2))

    get "/localities/suggestion", params: { latitude: "0", longitude: "0" }

    assert_response :ok
    assert_equal({ "locality" => { "name" => "Earlier" } }, response.parsed_body)
  end

  test "an earlier center wins a tie when the later center is staffed" do
    create_locality(name: "Earlier", latitude: 0, longitude: 0, created_at: Time.utc(2026, 1, 1))
    later = create_locality(name: "Later", latitude: 0, longitude: 0, created_at: Time.utc(2026, 1, 2))
    link_account(later)

    assert_no_difference [ "Locality.count", "Enrolment.count", "LocalityAssignment.count" ] do
      get "/localities/suggestion", params: { latitude: "0", longitude: "0" }
    end

    assert_response :ok
    assert_equal({ "locality" => { "name" => "Earlier" } }, response.parsed_body)
  end

  test "a missing coordinate pair returns 422 and writes nothing" do
    assert_rejected({ longitude: "0" }, "Latitude and longitude must both be present", "latitude" => [ "must be present with longitude" ])
    assert_rejected({ latitude: "0" }, "Latitude and longitude must both be present", "latitude" => [ "must be present with longitude" ])
    assert_rejected({}, "Latitude and longitude must both be present", "latitude" => [ "must be present with longitude" ])
    assert_rejected({ latitude: " ", longitude: "0" }, "Latitude and longitude must both be present", "latitude" => [ "must be present with longitude" ])
  end

  test "a coordinate that is not a number returns 422 and writes nothing" do
    assert_rejected({ latitude: "north", longitude: "0" }, "Latitude is not a number", "latitude" => [ "is not a number" ])
    assert_rejected({ latitude: "0", longitude: "east" }, "Longitude is not a number", "longitude" => [ "is not a number" ])
  end

  test "both invalid coordinates return both details" do
    assert_rejected(
      { latitude: "north", longitude: "east" },
      "Latitude is not a number",
      "latitude" => [ "is not a number" ], "longitude" => [ "is not a number" ]
    )
  end

  test "an out-of-range coordinate pair returns 422 and writes nothing" do
    assert_rejected({ latitude: "90.1", longitude: "0" }, "Latitude is out of range", "latitude" => [ "is out of range" ])
    assert_rejected({ latitude: "-90.1", longitude: "0" }, "Latitude is out of range", "latitude" => [ "is out of range" ])
    assert_rejected({ latitude: "0", longitude: "180.1" }, "Longitude is out of range", "longitude" => [ "is out of range" ])
    assert_rejected({ latitude: "0", longitude: "-180.1" }, "Longitude is out of range", "longitude" => [ "is out of range" ])
  end

  test "coordinates on the range boundary are accepted" do
    get "/localities/suggestion", params: { latitude: "90", longitude: "-180" }

    assert_response :ok
    assert_equal({ "locality" => nil }, response.parsed_body)
  end

  test "the suggestion returns the stored locality name" do
    create_locality(name: "Straße Weg", latitude: 0, longitude: 0, created_at: Time.utc(2026, 1, 1))

    get "/localities/suggestion", params: { latitude: "0", longitude: "0" }

    assert_response :ok
    assert_equal({ "locality" => { "name" => "Straße Weg" } }, response.parsed_body)
  end

  test "padded numeric coordinates are accepted" do
    create_locality(name: "Block 4", latitude: 0, longitude: 0, created_at: Time.utc(2026, 1, 1))

    get "/localities/suggestion", params: { latitude: " 0 ", longitude: " 0 " }

    assert_response :ok
    assert_equal({ "locality" => { "name" => "Block 4" } }, response.parsed_body)
  end

  private
    def create_locality(name:, created_at:, latitude: nil, longitude: nil, radius_metres: nil)
      travel_to(created_at) do
        Locality.create!(name:, latitude:, longitude:, radius_metres:)
      end
    end

    def assert_rejected(params, message, details)
      assert_no_difference [ "Locality.count", "Enrolment.count", "LocalityAssignment.count" ] do
        get "/localities/suggestion", params: params
      end

      assert_response :unprocessable_content
      error = response.parsed_body.fetch("error")
      assert_equal [ "code", "details", "message" ], error.keys.sort
      assert_equal "VALIDATION_ERROR", error["code"]
      assert_equal message, error["message"]
      assert_equal details, error["details"]
    end
end
