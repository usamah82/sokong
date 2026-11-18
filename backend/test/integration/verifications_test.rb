require "test_helper"

class VerificationsTest < ActionDispatch::IntegrationTest
  test "a linked worker stores a past visit and a visit later than a week" do
    travel_to Time.utc(2026, 11, 18, 2, 0, 0) do
      enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
      enrolment.update!(submitted_at: Time.utc(2026, 11, 1, 0, 0, 0))
      token = worker_token(name: "Aman", locality: enrolment.locality)
      before = enrolment.reload

      assert_enqueued_emails 1 do
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
      assert_enqueued_emails 1 do
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

      assert_enqueued_emails 1 do
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
      assert_no_enqueued_emails do
        assert_no_changes -> { enrolment.reload.attributes.slice("visit_at", "bringing_basket", "assigned_workers", "updated_at") } do
          patch "/enrolments/#{enrolment.id}/visit", params: params, headers: bearer(token), as: :json
        end
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

    assert_no_enqueued_emails do
      assert_no_difference "Enrolment.count" do
        patch "/enrolments/#{enrolment.id}/visit", params: body, as: :json
      end
    end
    assert_sign_in_required
    assert_nil enrolment.reload.visit_at

    submitter = confirmed_token(email: "siti@example.com")
    assert_no_enqueued_emails do
      patch "/enrolments/#{enrolment.id}/visit", params: body, headers: bearer(submitter), as: :json
    end
    assert_not_found

    stranger = worker_token(name: "Farid", locality: other)
    assert_no_enqueued_emails do
      patch "/enrolments/#{enrolment.id}/visit", params: body, headers: bearer(stranger), as: :json
    end
    assert_not_found

    unlinked = worker_token(name: "Noor")
    assert_no_enqueued_emails do
      patch "/enrolments/#{enrolment.id}/visit", params: body, headers: bearer(unlinked), as: :json
    end
    assert_not_found

    linked = worker_token(name: "Aman", locality: enrolment.locality)
    assert_no_enqueued_emails do
      patch "/enrolments/#{SecureRandom.uuid}/visit", params: body, headers: bearer(linked), as: :json
    end
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

    assert_no_enqueued_emails do
      patch "/enrolments/#{enrolment.id}/visit",
        params: "x" * (128 * 1024 + 1),
        headers: bearer(token).merge("CONTENT_TYPE" => "application/json")
    end

    assert_response :content_too_large
    error = response.parsed_body.fetch("error")
    assert_equal "PAYLOAD_TOO_LARGE", error["code"]
    assert_nil enrolment.reload.visit_at
    assert_nil enrolment.bringing_basket
    assert_nil enrolment.assigned_workers
  end

  test "the first visit time queues one message and a changed time queues another" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti Aminah", place: "Kampung Baru")
    add_member(enrolment, name: "Rahim", role: "child")
    enrolment.update!(family_phone: "+60123456789", enroler_contact: "+60198765432")
    token = worker_token(name: "Aman", locality: enrolment.locality)
    clear_enqueued_jobs
    ActionMailer::Base.deliveries.clear
    job_log = StringIO.new
    previous_logger = ActiveJob::Base.logger
    ActiveJob::Base.logger = ActiveSupport::Logger.new(job_log)
    previous_enforce = I18n.enforce_available_locales
    I18n.enforce_available_locales = false
    previous_locale = I18n.locale
    I18n.locale = :ms

    assert_enqueued_emails 1 do
      patch "/enrolments/#{enrolment.id}/visit",
        params: {
          visit_at: "2026-11-24T09:00:00+08:00",
          bringing_basket: true,
          assigned_workers: [ "Farid" ]
        },
        headers: bearer(token),
        as: :json
    end
    assert_response :ok
    assert_enqueued_email_with EnrolmentMailer, :visit_set, args: [
      "siti@example.com",
      "Siti Aminah",
      "Kampung Baru",
      "24 November 2026 at 01:00 UTC"
    ]

    assert_enqueued_emails 1 do
      patch "/enrolments/#{enrolment.id}/visit",
        params: {
          visit_at: "2026-11-25T01:00:00Z",
          bringing_basket: true,
          assigned_workers: [ "Farid" ]
        },
        headers: bearer(token),
        as: :json
    end
    assert_enqueued_email_with EnrolmentMailer, :visit_changed, args: [
      "siti@example.com",
      "Siti Aminah",
      "Kampung Baru",
      "25 November 2026 at 01:00 UTC"
    ]
    perform_enqueued_jobs
    assert_equal 2, ActionMailer::Base.deliveries.size
    first = ActionMailer::Base.deliveries.first
    changed = ActionMailer::Base.deliveries.last
    assert_equal [ "siti@example.com" ], first.to
    assert_equal "Sokong visit", first.subject
    assert_equal(
      "A visit is set for Siti Aminah at Kampung Baru. The visit time is 24 November 2026 at 01:00 UTC.",
      mail_text(first)
    )
    assert_visit_mail_is_only_the_sentence(first)
    assert_equal [ "siti@example.com" ], changed.to
    assert_equal "Sokong visit", changed.subject
    assert_equal(
      "The visit time for Siti Aminah at Kampung Baru is now 25 November 2026 at 01:00 UTC.",
      mail_text(changed)
    )
    assert_includes job_log.string, "Enqueued EnrolmentInvitationDeliveryJob"
    assert_not_includes job_log.string, "Siti Aminah"
    assert_not_includes job_log.string, "Kampung Baru"
    assert_not_includes job_log.string, "siti@example.com"
  ensure
    ActiveJob::Base.logger = previous_logger
    I18n.locale = previous_locale
    I18n.enforce_available_locales = previous_enforce
  end

  test "a blank email and an unchanged instant queue no visit message" do
    blank = submit_enrolment(email: "", name: "Siti")
    token = worker_token(name: "Aman", locality: blank.locality)
    assert_no_enqueued_emails do
      patch "/enrolments/#{blank.id}/visit",
        params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: false, assigned_workers: [ "Aman" ] },
        headers: bearer(token),
        as: :json
    end
    assert_response :ok

    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti")
    linked = worker_token(name: "Aman", locality: enrolment.locality)
    patch "/enrolments/#{enrolment.id}/visit",
      params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "Aman" ] },
      headers: bearer(linked),
      as: :json
    assert_response :ok
    assert_no_enqueued_emails do
      patch "/enrolments/#{enrolment.id}/visit",
        params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: false, assigned_workers: [ "Farid" ] },
        headers: bearer(linked),
        as: :json
    end
    assert_response :ok
    assert_equal false, enrolment.reload.bringing_basket
    assert_equal [ "Farid" ], enrolment.assigned_workers
  end

  test "a raised enqueue still saves the visit and logs the error class only" do
    enrolment = submit_enrolment(email: "siti@example.com", name: "Siti Aminah", place: "Kampung Baru")
    token = worker_token(name: "Aman", locality: enrolment.locality)
    previous = ActiveJob::Base.queue_adapter
    adapter = RaisingQueueAdapter.new
    ActiveJob::Base.queue_adapter = adapter
    log = StringIO.new
    logger = ActiveSupport::Logger.new(log)
    previous_logger = ActionController::API.logger
    ActionController::API.logger = logger
    ActionController::Base.logger = logger

    patch "/enrolments/#{enrolment.id}/visit",
      params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "Aman" ] },
      headers: bearer(token),
      as: :json

    assert_response :ok
    assert_equal 1, adapter.attempts
    enrolment.reload
    assert_equal Time.utc(2026, 11, 24, 1, 0, 0), enrolment.visit_at
    assert_equal true, enrolment.bringing_basket
    assert_includes log.string, "RuntimeError"
    assert_not_includes log.string, "Siti Aminah"
    assert_not_includes log.string, "Kampung Baru"
    assert_not_includes log.string, "siti@example.com"
    assert_not_includes log.string, "queue down"
  ensure
    ActiveJob::Base.queue_adapter = previous
    ActionController::API.logger = previous_logger
    ActionController::Base.logger = previous_logger
  end

  private
    def mail_text(mail)
      mail.text_part&.body&.to_s&.strip || mail.body.to_s.strip
    end

    def assert_visit_mail_is_only_the_sentence(mail)
      text = mail.body.to_s
      assert_not_includes text, "Rahim"
      assert_not_includes text, "+60123456789"
      assert_not_includes text, "+60198765432"
      assert_not_includes text, "Farid"
      assert_not_includes text, "true"
    end

    def add_member(enrolment, name:, role:)
      enrolment.family_unit.members.create!(
        role: role,
        position: enrolment.members.count,
        name: name,
        gender: "unspecified",
        description: "",
        in_education: false,
        working: false,
        job: ""
      )
    end

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

    def submit_enrolment(email:, name:, place: "Kampung Baru")
      post "/enrolments", params: valid_enrolment.merge(
        email: email,
        place_name: place,
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
        @attempts += 1
        raise "queue down"
      end
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
