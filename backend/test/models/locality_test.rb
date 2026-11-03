require "test_helper"

class LocalityTest < ActiveSupport::TestCase
  EARTH_RADIUS_METRES = 6_371_000

  test "a created record gets a 36-character id and orders by created_at" do
    later = create_locality(name: "Later", created_at: Time.utc(2026, 1, 2))
    earlier = create_locality(name: "Earlier", created_at: Time.utc(2026, 1, 1))

    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, earlier.id)
    assert_equal 36, earlier.id.length
    assert_equal earlier, Locality.first
    assert_equal later, Locality.last
  end

  test "no match creates a collapsed name with no center or radius" do
    locality = Locality.claim(place_name: "  Kampung \t  Baru  ", point: nil)

    assert_equal "Kampung Baru", locality.name
    assert_nil locality.latitude
    assert_nil locality.longitude
    assert_nil locality.radius_metres
    assert_equal 36, locality.id.length
    assert_equal 1, Locality.count
  end

  test "a normalized name match fits and does not change the locality" do
    existing = create_locality(
      name: "Straße Weg",
      latitude: 3,
      longitude: 101,
      radius_metres: 500,
      created_at: Time.utc(2026, 1, 1)
    )

    claimed = Locality.claim(place_name: "  strasse   weg ", point: [ 9, 9 ])

    assert_equal existing, claimed
    existing.reload
    assert_equal "Straße Weg", existing.name
    assert_equal 3, existing.latitude.to_f
    assert_equal 101, existing.longitude.to_f
    assert_equal 500, existing.radius_metres
    assert_equal 1, Locality.count
  end

  test "a point inside a circle fits when the name does not" do
    existing = create_locality(
      name: "Block 4",
      latitude: 0,
      longitude: 0,
      radius_metres: 1_000,
      created_at: Time.utc(2026, 1, 1)
    )

    claimed = Locality.claim(place_name: "Somewhere else", point: [ 0, degrees_east(100) ])

    assert_equal existing, claimed
  end

  test "a point exactly radius_metres from the center fits" do
    # A radius of 0 includes only the center, so the boundary check is exact.
    existing = create_locality(
      name: "Edge",
      latitude: 0,
      longitude: 0,
      radius_metres: 0,
      created_at: Time.utc(2026, 1, 1)
    )

    claimed = Locality.claim(place_name: "Elsewhere", point: [ 0, 0 ])

    assert_equal existing, claimed
  end

  test "a point outside every circle and a new name creates a locality" do
    create_locality(
      name: "Edge",
      latitude: 0,
      longitude: 0,
      radius_metres: 1_000,
      created_at: Time.utc(2026, 1, 1)
    )

    claimed = Locality.claim(place_name: "Elsewhere", point: [ 0, degrees_east(2_000) ])

    assert_equal "Elsewhere", claimed.name
    assert_nil claimed.latitude
    assert_nil claimed.longitude
    assert_nil claimed.radius_metres
    assert_equal 2, Locality.count
  end

  test "a staffed locality wins over a closer unstaffed locality" do
    closer = create_locality(
      name: "Closer",
      latitude: 0,
      longitude: 0,
      radius_metres: 5_000,
      created_at: Time.utc(2026, 1, 1)
    )
    staffed = create_locality(
      name: "Staffed",
      latitude: 0,
      longitude: degrees_east(2_000),
      radius_metres: 5_000,
      created_at: Time.utc(2026, 1, 2)
    )
    assignment = assign(staffed)

    assert_equal 36, assignment.id.length

    claimed = Locality.claim(place_name: "Neither", point: [ 0, 0 ])

    assert_equal staffed, claimed
    assert_not_equal closer, claimed
  end

  test "the shortest distance wins inside the staffed pool" do
    farther = create_locality(
      name: "Farther",
      latitude: 0,
      longitude: degrees_east(3_000),
      radius_metres: 5_000,
      created_at: Time.utc(2026, 1, 1)
    )
    nearer = create_locality(
      name: "Nearer",
      latitude: 0,
      longitude: degrees_east(1_000),
      radius_metres: 5_000,
      created_at: Time.utc(2026, 1, 2)
    )
    assign(farther)
    assign(nearer)
    create_locality(
      name: "Unstaffed at the point",
      latitude: 0,
      longitude: 0,
      radius_metres: 5_000,
      created_at: Time.utc(2026, 1, 1)
    )

    claimed = Locality.claim(place_name: "Neither", point: [ 0, 0 ])

    assert_equal nearer, claimed
  end

  test "the shortest distance wins when no match is staffed" do
    farther = create_locality(
      name: "Farther",
      latitude: 0,
      longitude: degrees_east(3_000),
      radius_metres: 5_000,
      created_at: Time.utc(2026, 1, 1)
    )
    nearer = create_locality(
      name: "Nearer",
      latitude: 0,
      longitude: degrees_east(1_000),
      radius_metres: 5_000,
      created_at: Time.utc(2026, 1, 2)
    )

    claimed = Locality.claim(place_name: "Neither", point: [ 0, 0 ])

    assert_equal nearer, claimed
    assert_not_equal farther, claimed
  end

  test "equal distance uses the earliest created_at" do
    earlier = create_locality(
      name: "Earlier",
      latitude: 0,
      longitude: 0,
      radius_metres: 1_000,
      created_at: Time.utc(2026, 1, 1)
    )
    later = create_locality(
      name: "Later",
      latitude: 0,
      longitude: 0,
      radius_metres: 1_000,
      created_at: Time.utc(2026, 1, 2)
    )

    claimed = Locality.claim(place_name: "Neither", point: [ 0, 0 ])

    assert_equal earlier, claimed
    assert_not_equal later, claimed
  end

  test "no point uses the earliest created_at after the staffed filter" do
    earlier = create_locality(name: "Block 4", created_at: Time.utc(2026, 1, 1))
    staffed = create_locality(name: "block 4", created_at: Time.utc(2026, 1, 3))
    create_locality(name: "Block 4", created_at: Time.utc(2026, 1, 2))
    assign(staffed)

    claimed = Locality.claim(place_name: "BLOCK 4", point: nil)

    assert_equal staffed, claimed
    assert_not_equal earlier, claimed
  end

  test "with no point and no staff the earliest name match wins" do
    earlier = create_locality(name: "Block 4", created_at: Time.utc(2026, 1, 1))
    create_locality(name: "Block 4", created_at: Time.utc(2026, 1, 2))

    claimed = Locality.claim(place_name: "Block 4", point: nil)

    assert_equal earlier, claimed
  end

  test "a fitting locality with no center loses to one with a numeric distance" do
    name_only = create_locality(name: "Block 4", created_at: Time.utc(2026, 1, 1))
    circled = create_locality(
      name: "Other",
      latitude: 0,
      longitude: 0,
      radius_metres: 1_000,
      created_at: Time.utc(2026, 1, 2)
    )

    claimed = Locality.claim(place_name: "Block 4", point: [ 0, degrees_east(100) ])

    assert_equal circled, claimed
    assert_not_equal name_only, claimed
  end

  test "among staffed matches a center still beats a locality with no center" do
    name_only = create_locality(name: "Block 4", created_at: Time.utc(2026, 1, 1))
    circled = create_locality(
      name: "Other",
      latitude: 0,
      longitude: 0,
      radius_metres: 1_000,
      created_at: Time.utc(2026, 1, 2)
    )
    assign(name_only)
    assign(circled)

    claimed = Locality.claim(place_name: "Block 4", point: [ 0, degrees_east(100) ])

    assert_equal circled, claimed
  end

  test "a staffed name match with no center wins over an unstaffed circle" do
    staffed = create_locality(name: "Block 4", created_at: Time.utc(2026, 1, 2))
    assign(staffed)
    create_locality(
      name: "Circle",
      latitude: 0,
      longitude: 0,
      radius_metres: 1_000,
      created_at: Time.utc(2026, 1, 1)
    )

    claimed = Locality.claim(place_name: "Block 4", point: [ 0, 0 ])

    assert_equal staffed, claimed
  end

  private
    def create_locality(name:, created_at:, latitude: nil, longitude: nil, radius_metres: nil)
      travel_to(created_at) do
        Locality.create!(name:, latitude:, longitude:, radius_metres:)
      end
    end

    def assign(locality)
      LocalityAssignment.create!(account_id: SecureRandom.uuid, locality:)
    end

    def degrees_east(metres)
      metres * 180 / (Math::PI * EARTH_RADIUS_METRES)
    end
end
