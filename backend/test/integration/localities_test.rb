require "test_helper"

class LocalitiesTest < ActionDispatch::IntegrationTest
  test "a linked worker sets the name and circle and an older enrolment stays put" do
    locality = Locality.create!(name: "Kampung Baru")
    post "/enrolments", params: {
      on_behalf: false,
      enroler_contact: "+60 12-345 6789",
      place_name: "Kampung Baru",
      members: [ { role: "head", name: "Siti", gender: "unspecified" } ]
    }, as: :json
    assert_response :created
    enrolment = Enrolment.order(:created_at).last
    assert_equal locality.id, enrolment.locality_id

    token = worker_token(locality)
    patch "/localities/#{locality.id}",
      params: { name: "  Block   4 ", latitude: 3.1, longitude: 101.7, radius_metres: 500 },
      headers: bearer(token),
      as: :json

    assert_response :ok
    locality.reload
    assert_equal(
      {
        "id" => locality.id,
        "name" => "Block 4",
        "latitude" => 3.1,
        "longitude" => 101.7,
        "radius_metres" => 500
      },
      response.parsed_body
    )
    assert_equal locality.id, enrolment.reload.locality_id
    assert_equal "Kampung Baru", enrolment.place_name
  end

  test "a radius without a center, a bad radius, or a bad name is rejected" do
    locality = Locality.create!(name: "Block 4", latitude: 1, longitude: 2, radius_metres: 10)
    token = worker_token(locality)

    patch "/localities/#{locality.id}",
      params: { radius_metres: 20, latitude: nil, longitude: nil },
      headers: bearer(token),
      as: :json
    assert_rejected "Radius requires a center", "radius_metres" => [ "requires a center" ]
    assert_equal 10, locality.reload.radius_metres

    patch "/localities/#{locality.id}",
      params: { radius_metres: 200_001 },
      headers: bearer(token),
      as: :json
    assert_rejected "Radius is out of range", "radius_metres" => [ "is out of range" ]

    patch "/localities/#{locality.id}",
      params: { name: "a" * 201 },
      headers: bearer(token),
      as: :json
    assert_rejected "Name is too long", "name" => [ "is too long" ]
    assert_equal "Block 4", locality.reload.name
  end

  test "null coordinates and a null radius clear the circle" do
    locality = Locality.create!(name: "Block 4", latitude: 1, longitude: 2, radius_metres: 10)
    token = worker_token(locality)

    patch "/localities/#{locality.id}",
      params: { latitude: nil, longitude: nil, radius_metres: nil },
      headers: bearer(token),
      as: :json

    assert_response :ok
    locality.reload
    assert_nil locality.latitude
    assert_nil locality.longitude
    assert_nil locality.radius_metres
    assert_equal "Block 4", locality.name
  end

  test "a submitter and a worker of another locality cannot edit it" do
    locality = Locality.create!(name: "Block 4")
    other = Locality.create!(name: "Other")
    submitter = confirmed_submitter
    stranger = worker_token(other)

    patch "/localities/#{locality.id}", params: { name: "Nope" }, headers: bearer(submitter), as: :json
    assert_not_found
    patch "/localities/#{locality.id}", params: { name: "Nope" }, headers: bearer(stranger), as: :json
    assert_not_found
    patch "/localities/#{SecureRandom.uuid}", params: { name: "Nope" }, headers: bearer(stranger), as: :json
    assert_not_found
    assert_equal "Block 4", locality.reload.name
  end

  private
    def worker_token(locality)
      account = Account.create!(
        email: "worker-#{SecureRandom.hex(4)}@example.com",
        password: "correct horse battery staple",
        role: "worker",
        name: "Aman",
        email_confirmed_at: Time.current
      )
      LocalityAssignment.create!(account:, locality:)
      post "/sessions", params: { email: account.email, password: "correct horse battery staple" }, as: :json
      assert_response :ok
      response.parsed_body.fetch("token")
    end

    def confirmed_submitter
      post "/accounts", params: {
        email: "siti@example.com",
        password: "correct horse battery staple",
        password_confirmation: "correct horse battery staple"
      }, as: :json
      assert_response :created
      perform_enqueued_jobs
      raw = ActionMailer::Base.deliveries.last.body.to_s[/token=([^&\s]+)/, 1]
      post "/account_verifications", params: { token: raw }, as: :json
      assert_response :no_content
      post "/sessions", params: { email: "siti@example.com", password: "correct horse battery staple" }, as: :json
      assert_response :ok
      response.parsed_body.fetch("token")
    end

    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def assert_rejected(message, details)
      assert_response :unprocessable_content
      error = response.parsed_body.fetch("error")
      assert_equal "VALIDATION_ERROR", error["code"]
      assert_equal message, error["message"]
      assert_equal details, error["details"]
    end

    def assert_not_found
      assert_response :not_found
      error = response.parsed_body.fetch("error")
      assert_equal [ "code", "message" ], error.keys.sort
      assert_equal "NOT_FOUND", error["code"]
      assert_equal "Not found", error["message"]
    end
end
