require "test_helper"

class VerificationsTest < ActionDispatch::IntegrationTest
  test "a linked worker stores a past visit and a visit later than a week" do
    travel_to Time.utc(2026, 11, 18, 2, 0, 0) do
      enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
      enrolment.update!(submitted_at: Time.utc(2026, 11, 1, 0, 0, 0))
      token = worker_token(name: "Aman", locality: enrolment.locality)
      before = enrolment.reload

      assert_no_enqueued_jobs do
        patch "/enrolments/#{enrolment.id}/visit",
          params: {
            visit_at: "2026-10-01T01:00:00Z",
            bringing_basket: true,
            assigned_workers: [ " Aman " ]
          },
          headers: bearer(token),
          as: :json
      end

      assert_response :ok
      assert_equal(
        {
          "visit_at" => "2026-10-01T01:00:00Z",
          "bringing_basket" => true,
          "assigned_workers" => [ "Aman" ]
        },
        response.parsed_body
      )
      enrolment.reload
      assert_equal Time.utc(2026, 10, 1, 1, 0, 0), enrolment.visit_at
      assert_equal true, enrolment.bringing_basket
      assert_equal [ "Aman" ], enrolment.assigned_workers
      assert_unchanged_case before, enrolment

      late = (enrolment.submitted_at + (7 * 24 * 60 * 60) + 1).utc.iso8601
      assert_no_enqueued_jobs do
        patch "/enrolments/#{enrolment.id}/visit",
          params: {
            visit_at: "2026-11-24T09:00:00+08:00",
            bringing_basket: false,
            assigned_workers: [ "Aman", " Farid " ]
          },
          headers: bearer(token),
          as: :json
      end
      assert_response :ok
      assert_equal "2026-11-24T01:00:00Z", response.parsed_body["visit_at"]
      assert_equal false, response.parsed_body["bringing_basket"]
      assert_equal [ "Aman", "Farid" ], response.parsed_body["assigned_workers"]

      assert_no_enqueued_jobs do
        patch "/enrolments/#{enrolment.id}/visit",
          params: {
            visit_at: late,
            bringing_basket: true,
            assigned_workers: ten_names
          },
          headers: bearer(token),
          as: :json
      end
      assert_response :ok
      assert_equal late, response.parsed_body["visit_at"]
      assert_equal ten_names, response.parsed_body["assigned_workers"]
      enrolment.reload
      assert_equal Time.iso8601(late), enrolment.visit_at
      assert_unchanged_case before, enrolment
    end
  end

  test "the same instant, checkbox, and names do not write" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
    token = worker_token(name: "Aman", locality: enrolment.locality)
    body = {
      visit_at: "2026-11-24T01:00:00.500Z",
      bringing_basket: true,
      assigned_workers: [ "Aman" ]
    }

    patch "/enrolments/#{enrolment.id}/visit", params: body, headers: bearer(token), as: :json
    assert_response :ok
    stored = enrolment.reload
    updated_at = stored.updated_at

    assert_no_enqueued_jobs do
      assert_no_changes -> { stored.reload.updated_at } do
        patch "/enrolments/#{enrolment.id}/visit",
          params: body.merge(visit_at: "2026-11-24T01:00:00Z"),
          headers: bearer(token),
          as: :json
      end
    end
    assert_response :ok
    assert_equal "2026-11-24T01:00:00Z", response.parsed_body["visit_at"]
    assert_equal updated_at, enrolment.reload.updated_at
  end

  test "the same instant with a different checkbox or names stores those fields and queues no mail" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
    token = worker_token(name: "Aman", locality: enrolment.locality)
    patch "/enrolments/#{enrolment.id}/visit",
      params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "Aman" ] },
      headers: bearer(token),
      as: :json
    assert_response :ok

    assert_no_enqueued_jobs do
      patch "/enrolments/#{enrolment.id}/visit",
        params: { visit_at: "2026-11-24T09:00:00+08:00", bringing_basket: false, assigned_workers: [ "Aman" ] },
        headers: bearer(token),
        as: :json
    end
    assert_response :ok
    enrolment.reload
    assert_equal Time.utc(2026, 11, 24, 1, 0, 0), enrolment.visit_at
    assert_equal false, enrolment.bringing_basket
    assert_equal [ "Aman" ], enrolment.assigned_workers

    assert_no_enqueued_jobs do
      patch "/enrolments/#{enrolment.id}/visit",
        params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: false, assigned_workers: [ "Farid" ] },
        headers: bearer(token),
        as: :json
    end
    assert_response :ok
    assert_equal [ "Farid" ], enrolment.reload.assigned_workers
  end

  test "a bad visit time, checkbox, or name list is 422 and leaves the stored fields" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
    token = worker_token(name: "Aman", locality: enrolment.locality)
    patch "/enrolments/#{enrolment.id}/visit",
      params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "Aman" ] },
      headers: bearer(token),
      as: :json
    assert_response :ok
    stored = enrolment.reload.attributes.slice("visit_at", "bringing_basket", "assigned_workers", "updated_at")

    [
      [ { bringing_basket: true, assigned_workers: [ "Aman" ] }, "Visit time is invalid", "visit_at" ],
      [ { visit_at: "", bringing_basket: true, assigned_workers: [ "Aman" ] }, "Visit time is invalid", "visit_at" ],
      [ { visit_at: "2026-11-24", bringing_basket: true, assigned_workers: [ "Aman" ] }, "Visit time is invalid", "visit_at" ],
      [ { visit_at: "2026-11-24T01:00:00", bringing_basket: true, assigned_workers: [ "Aman" ] }, "Visit time is invalid", "visit_at" ],
      [ { visit_at: "2026-02-31T01:00:00Z", bringing_basket: true, assigned_workers: [ "Aman" ] }, "Visit time is invalid", "visit_at" ],
      [ { visit_at: "2026-11-24T01:00:00Z", assigned_workers: [ "Aman" ] }, "Bringing a basket is invalid", "bringing_basket" ],
      [ { visit_at: "2026-11-24T01:00:00Z", bringing_basket: "true", assigned_workers: [ "Aman" ] }, "Bringing a basket is invalid", "bringing_basket" ],
      [ { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [] }, "Assigned worker is required", "assigned_workers" ],
      [ { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "  " ] }, "Assigned worker is required", "assigned_workers" ],
      [ { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "A" * 201 ] }, "Assigned worker is invalid", "assigned_workers" ],
      [ { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: eleven_names }, "Assigned worker is invalid", "assigned_workers" ]
    ].each do |params, message, key|
      assert_no_changes -> { enrolment.reload.attributes.slice("visit_at", "bringing_basket", "assigned_workers", "updated_at") } do
        patch "/enrolments/#{enrolment.id}/visit", params: params, headers: bearer(token), as: :json
      end
      assert_visit_invalid message, key
    end

    assert_equal stored, enrolment.reload.attributes.slice("visit_at", "bringing_basket", "assigned_workers", "updated_at")

    patch "/enrolments/#{enrolment.id}/visit",
      params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "A" * 200 ] },
      headers: bearer(token),
      as: :json
    assert_response :ok
    assert_equal [ "A" * 200 ], response.parsed_body["assigned_workers"]
  end

  test "anonymous, a submitter, another locality, an unlinked worker, and an unknown id are refused" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
    other = create_locality(name: "Other Block", created_at: Time.current)
    body = { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "Aman" ] }

    assert_no_difference "Enrolment.count" do
      patch "/enrolments/#{enrolment.id}/visit", params: body, as: :json
    end
    assert_sign_in_required
    assert_nil enrolment.reload.visit_at

    submitter = confirmed_token(email: "siti@example.com")
    patch "/enrolments/#{enrolment.id}/visit", params: body, headers: bearer(submitter), as: :json
    assert_not_found

    stranger = worker_token(name: "Farid", locality: other)
    patch "/enrolments/#{enrolment.id}/visit", params: body, headers: bearer(stranger), as: :json
    assert_not_found

    unlinked = worker_token(name: "Noor")
    patch "/enrolments/#{enrolment.id}/visit", params: body, headers: bearer(unlinked), as: :json
    assert_not_found

    linked = worker_token(name: "Aman", locality: enrolment.locality)
    patch "/enrolments/#{SecureRandom.uuid}/visit", params: body, headers: bearer(linked), as: :json
    assert_not_found
    assert_nil enrolment.reload.visit_at
  end

  test "worker detail returns the pre-visit fields and the list and submitter return only the time" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
    token = worker_token(name: "Aman", locality: enrolment.locality)
    patch "/enrolments/#{enrolment.id}/visit",
      params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "Aman" ] },
      headers: bearer(token),
      as: :json
    assert_response :ok

    get "/enrolments", headers: bearer(token)
    assert_response :ok
    row = response.parsed_body.find { |item| item["id"] == enrolment.id }
    assert_equal "2026-11-24T01:00:00Z", row["visit_at"]
    assert_not row.key?("bringing_basket")
    assert_not row.key?("assigned_workers")

    get "/enrolments/#{enrolment.id}", headers: bearer(token)
    assert_response :ok
    detail = response.parsed_body
    assert_equal "2026-11-24T01:00:00Z", detail["visit_at"]
    assert_equal true, detail["bringing_basket"]
    assert_equal [ "Aman" ], detail["assigned_workers"]

    submitter = confirmed_token(email: "siti@example.com")
    get "/enrolments/#{enrolment.id}", headers: bearer(submitter)
    assert_response :ok
    body = response.parsed_body
    assert_equal "2026-11-24T01:00:00Z", body.dig("progress", "visit_at")
    assert_not body.key?("bringing_basket")
    assert_not body.key?("assigned_workers")
    assert_not body.key?("verification")
    assert_not body["progress"].key?("bringing_basket")
    assert_not body["progress"].key?("assigned_workers")

    get "/enrolments", headers: bearer(submitter)
    assert_response :ok
    listed = response.parsed_body.find { |item| item["id"] == enrolment.id }
    assert_equal "2026-11-24T01:00:00Z", listed.dig("progress", "visit_at")
    assert_not listed.key?("bringing_basket")
    assert_not listed.key?("assigned_workers")

    post "/enrolments", params: valid_enrolment.merge(email: "aminah@example.com"), as: :json
    assert_response :created
    created = response.parsed_body
    assert_nil created.dig("progress", "visit_at")
    assert_not created.key?("bringing_basket")
    assert_not created.key?("assigned_workers")
    assert_not created.key?("visit_at")
  end

  test "a body over 128 KiB on the visit route returns 413 and stores nothing" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
    token = worker_token(name: "Aman", locality: enrolment.locality)

    patch "/enrolments/#{enrolment.id}/visit",
      params: "x" * (128 * 1024 + 1),
      headers: bearer(token).merge("CONTENT_TYPE" => "application/json")

    assert_response :content_too_large
    error = response.parsed_body.fetch("error")
    assert_equal "PAYLOAD_TOO_LARGE", error["code"]
    assert_nil enrolment.reload.visit_at
    assert_nil enrolment.bringing_basket
    assert_nil enrolment.assigned_workers
  end

  private
    def ten_names
      (1..10).map { |index| "Worker #{index}" }
    end

    def eleven_names
      (1..11).map { |index| "Worker #{index}" }
    end

    def assert_unchanged_case(before, after)
      assert_equal before.place_name, after.place_name
      assert_equal before.consent_text, after.consent_text
      assert_equal before.members.map { |member| [ member.id, member.name, member.role ] },
        after.members.map { |member| [ member.id, member.name, member.role ] }
    end

    def assert_visit_invalid(message, key)
      assert_response :unprocessable_content
      error = response.parsed_body.fetch("error")
      assert_equal [ "code", "details", "message" ], error.keys.sort
      assert_equal "VALIDATION_ERROR", error["code"]
      assert_equal message, error["message"]
      detail = message == "Assigned worker is required" ? "is required" : "is invalid"
      assert_equal [ detail ], error.dig("details", key)
    end

    def assert_sign_in_required
      assert_response :unauthorized
      assert_equal "UNAUTHENTICATED", response.parsed_body.dig("error", "code")
      assert_equal "Sign in is required", response.parsed_body.dig("error", "message")
    end

    def assert_not_found
      assert_response :not_found
      error = response.parsed_body.fetch("error")
      assert_equal "NOT_FOUND", error["code"]
      assert_equal "Not found", error["message"]
    end

    def create_locality(name:, created_at:)
      travel_to(created_at) { Locality.create!(name:) }
    end

    def valid_enrolment
      {
        on_behalf: false,
        consent_text: "client sentence that must be ignored",
        enroler_contact: "+60 12-345 6789",
        place_name: "Kampung Baru",
        family_phone: "",
        how_to_find: "",
        help: [],
        other_help: "",
        members: [ { role: "head", name: "Siti", gender: "unspecified" } ]
      }
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
end
