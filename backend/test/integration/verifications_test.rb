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

  test "the interview is on the linked worker's detail and nowhere else" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    other = create_locality(name: "Other Block", created_at: Time.current)

    get "/enrolments/#{enrolment.id}", headers: bearer(token)
    assert_response :ok
    before = response.parsed_body
    assert_includes before.keys, "verification"
    assert_nil before["verification"]
    assert_equal false, before["bringing_basket"]
    assert_equal [ "Aman" ], before["assigned_workers"]
    assert_includes before.keys, "marked_at"
    assert_nil before["marked_at"]
    assert_includes before.keys, "marker_name"
    assert_nil before["marker_name"]
    assert_includes before.keys, "outcome"
    assert_nil before["outcome"]

    body = who_is_here_body(enrolment)
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: body, headers: bearer(token), as: :json
    assert_response :ok
    saved = response.parsed_body

    get "/enrolments/#{enrolment.id}", headers: bearer(token)
    assert_response :ok
    detail = response.parsed_body
    assert_equal saved, detail.dig("verification", "who_is_here")
    %w[formation daily_life dynamics house needs boxes].each do |part|
      assert_nil detail.dig("verification", part)
    end
    assert_nil detail["marked_at"]
    assert_nil detail["marker_name"]
    assert_nil detail["outcome"]

    get "/enrolments", headers: bearer(token)
    assert_response :ok
    row = response.parsed_body.find { |item| item["id"] == enrolment.id }
    assert_equal "2026-11-24T01:00:00Z", row["visit_at"]
    assert_not row.key?("verification")
    assert_not row.key?("bringing_basket")
    assert_not row.key?("assigned_workers")

    submitter = confirmed_token(email: "siti@example.com")
    get "/enrolments/#{enrolment.id}", headers: bearer(submitter)
    assert_response :ok
    shown = response.parsed_body
    assert_not shown.key?("verification")
    assert_not shown.key?("bringing_basket")
    assert_not shown.key?("assigned_workers")
    get "/enrolments", headers: bearer(submitter)
    assert_response :ok
    listed = response.parsed_body.find { |item| item["id"] == enrolment.id }
    assert_not listed.key?("verification")
    assert_not listed.key?("bringing_basket")
    assert_not listed.key?("assigned_workers")

    stranger = confirmed_token(email: "aminah@example.com")
    get "/enrolments/#{enrolment.id}", headers: bearer(stranger)
    assert_not_found
    farid = worker_token(name: "Farid", locality: other)
    get "/enrolments/#{enrolment.id}", headers: bearer(farid)
    assert_not_found
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

  test "a linked worker saves Who is here and a second save replaces that column" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    head = enrolment.members.find { |member| member.role == "head" }
    child = enrolment.members.find { |member| member.role == "member" }
    added = added_person.merge(absent_since: "not-a-date", absent_reason: "Away")
    body = {
      people: [
        person_for(
          head,
          name: " Siti Aminah ",
          phone: "+60 12-345 6789",
          birth_date: "2024-02-29",
          gender: "female",
          identity: "verified",
          origin: "Kedah",
          relationship: "spouse",
          documents: [
            { kind: "passport", number: " P1 ", other_label: "nope" },
            { kind: "national_id", number: "900101", other_label: "ignore" },
            { kind: "other", number: "1", other_label: " Village letter " }
          ]
        ),
        person_for(child, relationship: "child", origin: "x" * 201, documents: []),
        added
      ],
      others_stay: false,
      others_stay_detail: "y" * 2001,
      care_for_parents: true,
      care_for_parents_detail: " Mother ",
      notes: "They spoke quietly",
      worker_name: "Hacker",
      recorded_at: "1999-01-01T00:00:00Z",
      wealth: "hidden"
    }
    body[:people][0][:secret] = "hidden"
    before = {
      members: enrolment.members.map { |member| [ member.id, member.name, member.role ] },
      place: enrolment.place_name,
      consent: enrolment.consent_text,
      contact: enrolment.enroler_contact,
      phone: enrolment.family_phone
    }

    travel_to Time.utc(2026, 11, 18, 3, 0, 0) do
      assert_no_enqueued_emails do
        put "/enrolments/#{enrolment.id}/verification/who_is_here",
          params: body, headers: bearer(token), as: :json
      end
    end

    assert_response :ok
    saved = response.parsed_body
    assert_equal "Aman", saved["worker_name"]
    assert_equal "2026-11-18T03:00:00Z", saved["recorded_at"]
    assert_nil saved["wealth"]
    head_saved = saved["people"][0]
    assert_equal "Siti Aminah", head_saved["name"]
    assert_equal "+60123456789", head_saved["phone"]
    assert_equal "2024-02-29", head_saved["birth_date"]
    assert_equal "female", head_saved["gender"]
    assert_equal true, head_saved["head"]
    assert_equal "", head_saved["relationship"]
    assert_equal "verified", head_saved["identity"]
    assert_equal head.id, head_saved["family_member_id"]
    assert_equal "Kedah", head_saved["origin"]
    assert_nil head_saved["secret"]
    assert_equal "passport", head_saved["documents"][0]["kind"]
    assert_equal "P1", head_saved["documents"][0]["number"]
    assert_equal "", head_saved["documents"][0]["other_label"]
    assert_equal "national_id", head_saved["documents"][1]["kind"]
    assert_equal "", head_saved["documents"][1]["other_label"]
    assert_equal "other", head_saved["documents"][2]["kind"]
    assert_equal "Village letter", head_saved["documents"][2]["other_label"]
    child_saved = saved["people"][1]
    assert_equal false, child_saved["head"]
    assert_equal "child", child_saved["relationship"]
    assert_equal child.id, child_saved["family_member_id"]
    assert_equal "", child_saved["origin"]
    assert_equal [], child_saved["documents"]
    added_saved = saved["people"][2]
    assert_equal false, added_saved["head"]
    assert_nil added_saved["family_member_id"]
    assert_equal "other", added_saved["relationship"]
    assert_equal "no_papers", added_saved["identity"]
    assert_equal "Johor", added_saved["origin"]
    assert_equal "", added_saved["absent_since"]
    assert_equal "", added_saved["absent_reason"]
    assert_equal "", saved["others_stay_detail"]
    assert_equal "Mother", saved["care_for_parents_detail"]
    stored = enrolment.reload.verification
    assert_equal saved, stored.who_is_here
    assert_nil stored.formation
    assert_nil stored.daily_life
    assert_nil stored.dynamics
    assert_nil stored.house
    assert_nil stored.needs
    assert_nil stored.boxes
    kept = enrolment.reload
    assert_equal before[:members], kept.members.map { |member| [ member.id, member.name, member.role ] }
    assert_equal before[:place], kept.place_name
    assert_equal before[:consent], kept.consent_text
    assert_equal before[:contact], kept.enroler_contact
    assert_equal before[:phone], kept.family_phone

    body[:notes] = "Second visit note"
    body[:people][2][:absent] = true
    body[:people][2][:absent_since] = "2024-01-02"
    body[:people][2][:absent_reason] = "Work"
    lina = worker_token(name: "Lina", locality: enrolment.locality)
    travel_to Time.utc(2026, 11, 18, 4, 0, 0) do
      assert_no_enqueued_emails do
        put "/enrolments/#{enrolment.id}/verification/who_is_here",
          params: body, headers: bearer(lina), as: :json
      end
    end
    assert_response :ok
    replaced = response.parsed_body
    assert_equal "Lina", replaced["worker_name"]
    assert_equal "2026-11-18T04:00:00Z", replaced["recorded_at"]
    assert_equal "Second visit note", replaced["notes"]
    assert_equal "2024-01-02", replaced["people"][2]["absent_since"]
    assert_equal "Work", replaced["people"][2]["absent_reason"]
    assert_equal 1, Verification.count
    reloaded = enrolment.verification.reload
    assert_equal replaced, reloaded.who_is_here
    assert_nil reloaded.formation
    assert_nil reloaded.daily_life
    assert_nil reloaded.dynamics
    assert_nil reloaded.house
    assert_nil reloaded.needs
    assert_nil reloaded.boxes
  end

  test "Who is here rejects a missing visit, a missing person, and a bad answer" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    head = enrolment.members.find { |member| member.role == "head" }
    child = enrolment.members.find { |member| member.role == "member" }
    body = {
      people: [ person_for(head), person_for(child, relationship: "spouse", origin: "Kedah") ],
      others_stay: nil,
      others_stay_detail: "",
      care_for_parents: nil,
      care_for_parents_detail: "",
      notes: ""
    }

    assert_no_difference "Verification.count" do
      put "/enrolments/#{enrolment.id}/verification/wealth",
        params: body, headers: bearer(token), as: :json
      assert_not_found
      put "/enrolments/#{enrolment.id}/verification/who_is_here",
        params: body, headers: bearer(token), as: :json
    end
    assert_stage_error "Set the visit before recording it", {}

    set_visit(enrolment, token)
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: body, headers: bearer(token), as: :json
    assert_response :ok
    stored = enrolment.verification.reload.who_is_here

    omitted = body.merge(people: [ person_for(head) ])
    assert_no_changes -> { enrolment.verification.reload.who_is_here } do
      put "/enrolments/#{enrolment.id}/verification/who_is_here",
        params: omitted, headers: bearer(token), as: :json
    end
    assert_stage_error "Person is required", "family_member_id" => [ "is required" ]

    bad_phone = body.deep_dup
    bad_phone[:people][0][:phone] = "Mary"
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: bad_phone, headers: bearer(token), as: :json
    assert_stage_error "Enter a phone number, for example +60 12-345 6789.", "phone" => [ "is invalid" ]

    [
      [ :birth_date, "2026-02-31", "Birth date is invalid", "birth_date" ],
      [ :identity, "maybe", "Identity check is invalid", "identity" ],
      [ :name, "A" * 201, "Full name is too long", "name" ],
      [ :absent, "yes", "Absent is invalid", "absent" ]
    ].each do |field, value, message, detail|
      changed = body.deep_dup
      changed[:people][0][field] = value
      put "/enrolments/#{enrolment.id}/verification/who_is_here",
        params: changed, headers: bearer(token), as: :json
      assert_stage_error message, detail => [ field == :name ? "is too long" : "is invalid" ]
    end

    unknown = body.deep_dup
    unknown[:people][0][:family_member_id] = SecureRandom.uuid
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: unknown, headers: bearer(token), as: :json
    assert_stage_error "Person is invalid", "family_member_id" => [ "is invalid", "is required" ]

    duplicate = body.deep_dup
    duplicate[:people][1][:person_id] = duplicate[:people][0][:person_id]
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: duplicate, headers: bearer(token), as: :json
    assert_stage_error "Person is invalid", "person_id" => [ "is invalid" ]

    bad_document = body.deep_dup
    bad_document[:people][0][:documents] = [ { kind: "library_card", number: "1", other_label: "" } ]
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: bad_document, headers: bearer(token), as: :json
    assert_stage_error "Document is invalid", "kind" => [ "is invalid" ]

    missing_number = body.deep_dup
    missing_number[:people][0][:documents] = [ { kind: "national_id", number: "  ", other_label: "" } ]
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: missing_number, headers: bearer(token), as: :json
    assert_stage_error "Document number is required", "number" => [ "is required" ]

    missing_label = body.deep_dup
    missing_label[:people][0][:documents] = [ { kind: "other", number: "1", other_label: "" } ]
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: missing_label, headers: bearer(token), as: :json
    assert_stage_error "What document? is required", "other_label" => [ "is required" ]

    assert_equal stored, enrolment.verification.reload.who_is_here

    put "/enrolments/#{enrolment.id}/verification/wealth",
      params: body, headers: bearer(token), as: :json
    assert_not_found
    assert_equal stored, enrolment.verification.reload.who_is_here

    put "/enrolments/#{enrolment.id}/verification/who_is_here", params: body, as: :json
    assert_sign_in_required
    assert_equal stored, enrolment.verification.reload.who_is_here

    submitter = confirmed_token(email: "siti@example.com")
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: body, headers: bearer(submitter), as: :json
    assert_not_found
    assert_equal stored, enrolment.verification.reload.who_is_here
  end

  test "Who is here stays hidden from another locality, an unlinked worker, and an unknown id" do
    enrolment = submit_family
    other = create_locality(name: "Other Block", created_at: Time.current)
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    body = who_is_here_body(enrolment)

    [ worker_token(name: "Farid", locality: other), worker_token(name: "Noor") ].each do |refused|
      assert_no_difference "Verification.count" do
        put "/enrolments/#{enrolment.id}/verification/who_is_here",
          params: body, headers: bearer(refused), as: :json
      end
      assert_not_found
    end

    assert_no_difference "Verification.count" do
      put "/enrolments/#{SecureRandom.uuid}/verification/who_is_here",
        params: body, headers: bearer(token), as: :json
    end
    assert_not_found
    assert_nil enrolment.reload.verification
  end

  test "Who is here collects every field error and rejects a person who cannot be stored" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    head = enrolment.members.find { |member| member.role == "head" }
    body = who_is_here_body(enrolment)
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: body, headers: bearer(token), as: :json
    assert_response :ok
    stored = enrolment.verification.reload.who_is_here

    both = body.deep_dup
    both[:people][0][:birth_date] = "2026-02-31"
    both[:people][0][:phone] = "Mary"
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: both, headers: bearer(token), as: :json
    assert_stage_error "Birth date is invalid",
      "birth_date" => [ "is invalid" ],
      "phone" => [ "is invalid" ]

    omitted = body.deep_dup
    omitted[:people] = [ person_for(head, phone: "Mary") ]
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: omitted, headers: bearer(token), as: :json
    assert_stage_error "Person is required",
      "family_member_id" => [ "is required" ],
      "phone" => [ "is invalid" ]

    origin = body.deep_dup
    origin[:people][1][:origin] = "z" * 201
    origin[:people][1][:relationship] = "cousin"
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: origin, headers: bearer(token), as: :json
    assert_stage_error "From where? is too long",
      "origin" => [ "is too long" ],
      "relationship" => [ "is invalid" ]

    blank_name = body.deep_dup
    blank_name[:people] << added_person.merge(name: "  ")
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: blank_name, headers: bearer(token), as: :json
    assert_stage_error "Full name is required", "name" => [ "is required" ]

    repeated = body.deep_dup
    repeated[:people] << person_for(head)
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: repeated, headers: bearer(token), as: :json
    assert_stage_error "Person is invalid", "family_member_id" => [ "is invalid" ]

    child_as_head = body.deep_dup
    child_as_head[:people][1][:head] = true
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: child_as_head, headers: bearer(token), as: :json
    assert_stage_error "Relationship is invalid", "relationship" => [ "is invalid" ]

    head_not_head = body.deep_dup
    head_not_head[:people][0][:head] = false
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: head_not_head, headers: bearer(token), as: :json
    assert_stage_error "Relationship is invalid", "relationship" => [ "is invalid" ]

    added_as_head = body.deep_dup
    added_as_head[:people] << added_person.merge(head: true)
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: added_as_head, headers: bearer(token), as: :json
    assert_stage_error "Relationship is invalid", "relationship" => [ "is invalid" ]

    cousin = body.deep_dup
    cousin[:people][1][:relationship] = "cousin"
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: cousin, headers: bearer(token), as: :json
    assert_stage_error "Relationship is invalid", "relationship" => [ "is invalid" ]

    bad_gender = body.deep_dup
    bad_gender[:people][0][:gender] = "other"
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: bad_gender, headers: bearer(token), as: :json
    assert_stage_error "Gender is invalid", "gender" => [ "is invalid" ]

    long_notes = body.deep_dup
    long_notes[:notes] = "n" * 2001
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: long_notes, headers: bearer(token), as: :json
    assert_stage_error "Anything else they said is too long", "notes" => [ "is too long" ]

    long_origin = body.deep_dup
    long_origin[:people][1][:origin] = "o" * 201
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: long_origin, headers: bearer(token), as: :json
    assert_stage_error "From where? is too long", "origin" => [ "is too long" ]

    long_why = body.deep_dup
    long_why[:people][1][:absent] = true
    long_why[:people][1][:absent_reason] = "w" * 2001
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: long_why, headers: bearer(token), as: :json
    assert_stage_error "Why is too long", "absent_reason" => [ "is too long" ]

    long_number = body.deep_dup
    long_number[:people][0][:documents] = [ { kind: "passport", number: "1" * 101, other_label: "" } ]
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: long_number, headers: bearer(token), as: :json
    assert_stage_error "Document number is too long", "number" => [ "is too long" ]

    long_label = body.deep_dup
    long_label[:people][0][:documents] = [ { kind: "other", number: "1", other_label: "d" * 101 } ]
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: long_label, headers: bearer(token), as: :json
    assert_stage_error "What document? is too long", "other_label" => [ "is too long" ]

    long_stay = body.deep_dup
    long_stay[:others_stay] = true
    long_stay[:others_stay_detail] = "s" * 2001
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: long_stay, headers: bearer(token), as: :json
    assert_stage_error "Who, and why? is too long", "others_stay_detail" => [ "is too long" ]

    missing_people = body.except(:people)
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: missing_people, headers: bearer(token), as: :json
    assert_stage_error "Person is required", "family_member_id" => [ "is required" ]

    string_people = body.merge(people: "nope")
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: string_people, headers: bearer(token), as: :json
    assert_stage_error "Person is required", "family_member_id" => [ "is required" ]

    string_person = body.deep_dup
    string_person[:people] << "nope"
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: string_person, headers: bearer(token), as: :json
    assert_stage_error "Person is invalid", "person_id" => [ "is invalid" ]

    bad_id = body.deep_dup
    bad_id[:people][0][:person_id] = "nope"
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: bad_id, headers: bearer(token), as: :json
    assert_stage_error "Person is invalid", "person_id" => [ "is invalid" ]

    number_name = body.deep_dup
    number_name[:people][0][:name] = 12
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: number_name, headers: bearer(token), as: :json
    assert_stage_error "Full name is invalid", "name" => [ "is invalid" ]

    number_phone = body.deep_dup
    number_phone[:people][0][:phone] = 12
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: number_phone, headers: bearer(token), as: :json
    assert_stage_error "Enter a phone number, for example +60 12-345 6789.", "phone" => [ "is invalid" ]

    string_documents = body.deep_dup
    string_documents[:people][0][:documents] = "passport"
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: string_documents, headers: bearer(token), as: :json
    assert_stage_error "Document is invalid", "kind" => [ "is invalid" ]

    string_document = body.deep_dup
    string_document[:people][0][:documents] = [ "passport" ]
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: string_document, headers: bearer(token), as: :json
    assert_stage_error "Document is invalid", "kind" => [ "is invalid" ]

    assert_equal stored, enrolment.verification.reload.who_is_here
  end

  test "Who is here stores a blank relationship, a null answer, and a string at its limit" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    body = who_is_here_body(enrolment)
    body[:people][1][:relationship] = ""
    body[:people][1][:absent] = nil
    body[:people][1][:absent_since] = "not-a-date"
    body[:people][1][:absent_reason] = "w" * 2001
    body[:others_stay] = nil
    body[:care_for_parents] = nil
    body[:people][0][:name] = "n" * 200
    body[:people][0][:origin] = "o" * 200
    body[:notes] = "e" * 2000
    away = added_person.merge(absent: true, absent_since: "", absent_reason: "w" * 2000)
    body[:people] << away
    body[:people][0][:documents] = [ { kind: "other", number: "1" * 100, other_label: "d" * 100 } ]

    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: body, headers: bearer(token), as: :json

    assert_response :ok
    saved = enrolment.verification.reload.who_is_here
    assert_equal "", saved["people"][0]["relationship"]
    assert_equal "n" * 200, saved["people"][0]["name"]
    assert_equal "o" * 200, saved["people"][0]["origin"]
    assert_equal "1" * 100, saved["people"][0]["documents"][0]["number"]
    assert_equal "d" * 100, saved["people"][0]["documents"][0]["other_label"]
    assert_equal "", saved["people"][1]["relationship"]
    assert_nil saved["people"][1]["absent"]
    assert_equal "", saved["people"][1]["absent_since"]
    assert_equal "", saved["people"][1]["absent_reason"]
    assert_equal true, saved["people"][2]["absent"]
    assert_equal "", saved["people"][2]["absent_since"]
    assert_equal "w" * 2000, saved["people"][2]["absent_reason"]
    assert_nil saved["others_stay"]
    assert_equal "", saved["others_stay_detail"]
    assert_nil saved["care_for_parents"]
    assert_equal "e" * 2000, saved["notes"]
  end

  test "formation and dynamics save on their own" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    blank = { started_year: nil, how_it_started: "", notes: "" }

    assert_no_difference "Verification.count" do
      put "/enrolments/#{enrolment.id}/verification/formation",
        params: blank, headers: bearer(token), as: :json
    end
    assert_stage_error "Set the visit before recording it", {}

    set_visit(enrolment, token)
    travel_to Time.utc(2026, 6, 1, 0, 0, 0) do
      assert_no_enqueued_emails do
        put "/enrolments/#{enrolment.id}/verification/formation",
          params: blank, headers: bearer(token), as: :json
      end
      assert_response :ok
      assert_nil response.parsed_body["started_year"]
      assert_equal "", response.parsed_body["how_it_started"]
      assert_equal "", response.parsed_body["notes"]
      assert_equal "Aman", response.parsed_body["worker_name"]
      assert_equal "2026-06-01T00:00:00Z", response.parsed_body["recorded_at"]

      put "/enrolments/#{enrolment.id}/verification/formation",
        params: { started_year: nil, wealth: "hidden" },
        headers: bearer(token), as: :json
      assert_response :ok
      assert_equal "", response.parsed_body["how_it_started"]
      assert_equal "", response.parsed_body["notes"]
      assert_not response.parsed_body.key?("wealth")

      filled = { started_year: 2026, how_it_started: " They married ", notes: "Quiet", worker_name: "Hacker", wealth: "hidden" }
      put "/enrolments/#{enrolment.id}/verification/formation",
        params: filled, headers: bearer(token), as: :json
      assert_response :ok
      assert_equal 2026, response.parsed_body["started_year"]
      assert_equal "They married", response.parsed_body["how_it_started"]
      assert_equal "Quiet", response.parsed_body["notes"]
      assert_equal "Aman", response.parsed_body["worker_name"]
      assert_not response.parsed_body.key?("wealth")

      put "/enrolments/#{enrolment.id}/verification/formation",
        params: { started_year: 1900, how_it_started: "", notes: "" },
        headers: bearer(token), as: :json
      assert_response :ok
      assert_equal 1900, response.parsed_body["started_year"]
      stored = enrolment.verification.reload.formation

      [
        [ { started_year: "2008", how_it_started: "", notes: "" }, "Enter the year, for example 2008." ],
        [ { started_year: 1899, how_it_started: "", notes: "" }, "Enter the year, for example 2008." ],
        [ { started_year: 2027, how_it_started: "", notes: "" }, "Enter the year, for example 2008." ],
        [ { started_year: 2008.0, how_it_started: "", notes: "" }, "Enter the year, for example 2008." ]
      ].each do |params, message|
        put "/enrolments/#{enrolment.id}/verification/formation",
          params: params, headers: bearer(token), as: :json
        assert_stage_error message, "started_year" => [ "is invalid" ]
      end
      assert_equal stored, enrolment.verification.reload.formation

      put "/enrolments/#{enrolment.id}/verification/formation",
        params: { started_year: 1900, how_it_started: "h" * 2001, notes: "" },
        headers: bearer(token), as: :json
      assert_stage_error "How did it start? is too long", "how_it_started" => [ "is too long" ]
      put "/enrolments/#{enrolment.id}/verification/formation",
        params: { started_year: 1900, how_it_started: 12, notes: "" },
        headers: bearer(token), as: :json
      assert_stage_error "How did it start? is invalid", "how_it_started" => [ "is invalid" ]
      put "/enrolments/#{enrolment.id}/verification/formation",
        params: { started_year: "2008", how_it_started: "", notes: "n" * 2001 },
        headers: bearer(token), as: :json
      assert_stage_error "Enter the year, for example 2008.",
        "started_year" => [ "is invalid" ],
        "notes" => [ "is too long" ]
      put "/enrolments/#{enrolment.id}/verification/formation",
        params: { started_year: 1900, how_it_started: "", notes: "n" * 2001 },
        headers: bearer(token), as: :json
      assert_stage_error "Anything else they said is too long", "notes" => [ "is too long" ]
      [ "", " 2008 " ].each do |year|
        put "/enrolments/#{enrolment.id}/verification/formation",
          params: { started_year: year, how_it_started: "", notes: "" },
          headers: bearer(token), as: :json
        assert_stage_error "Enter the year, for example 2008.", "started_year" => [ "is invalid" ]
      end
      assert_equal stored, enrolment.verification.reload.formation

      trimmed = " #{'a' * 2000} "
      put "/enrolments/#{enrolment.id}/verification/formation",
        params: { started_year: 1900, how_it_started: trimmed, notes: "" },
        headers: bearer(token), as: :json
      assert_response :ok
      assert_equal "a" * 2000, response.parsed_body["how_it_started"]
    end

    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: "", who_steps_in: "", children_at_home: "They play", notes: "", wealth: "hidden" },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "", response.parsed_body["hard_week"]
    assert_equal "", response.parsed_body["who_steps_in"]
    assert_equal "", response.parsed_body["children_at_home"]
    assert_equal "", response.parsed_body["notes"]
    assert_not response.parsed_body.key?("wealth")
    dynamics = enrolment.verification.reload.dynamics
    formation = enrolment.verification.formation

    spouse = who_is_here_body(enrolment)
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: spouse, headers: bearer(token), as: :json
    assert_response :ok
    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: "", who_steps_in: "", children_at_home: "They play", notes: "" },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "", response.parsed_body["children_at_home"]

    who = who_is_here_body(enrolment)
    who[:people][1][:relationship] = "child"
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: who, headers: bearer(token), as: :json
    assert_response :ok
    who_saved = enrolment.verification.reload.who_is_here
    assert_equal formation, enrolment.verification.formation

    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { children_at_home: "They play", wealth: "hidden" },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "", response.parsed_body["hard_week"]
    assert_equal "", response.parsed_body["who_steps_in"]
    assert_equal "", response.parsed_body["notes"]
    assert_equal "They play", response.parsed_body["children_at_home"]
    assert_not response.parsed_body.key?("wealth")

    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: " Long ", who_steps_in: "Aunt", children_at_home: " They play ", notes: "n" * 2000 },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "They play", response.parsed_body["children_at_home"]
    assert_equal "Long", response.parsed_body["hard_week"]
    assert_equal "Aunt", response.parsed_body["who_steps_in"]
    assert_equal "n" * 2000, response.parsed_body["notes"]
    assert_equal who_saved, enrolment.verification.reload.who_is_here
    assert_equal formation, enrolment.verification.formation

    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: " #{'b' * 2000} ", who_steps_in: "", children_at_home: "", notes: "" },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "b" * 2000, response.parsed_body["hard_week"]
    kept = enrolment.verification.reload.dynamics

    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: "", who_steps_in: "", children_at_home: "c" * 2001, notes: "" },
      headers: bearer(token), as: :json
    assert_stage_error "How are the children at home? is too long", "children_at_home" => [ "is too long" ]
    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: 12, who_steps_in: "", children_at_home: "", notes: "" },
      headers: bearer(token), as: :json
    assert_stage_error "What does a hard week look like here? is invalid", "hard_week" => [ "is invalid" ]
    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: "h" * 2001, who_steps_in: "", children_at_home: "", notes: "n" * 2001 },
      headers: bearer(token), as: :json
    assert_stage_error "What does a hard week look like here? is too long",
      "hard_week" => [ "is too long" ],
      "notes" => [ "is too long" ]
    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: "", who_steps_in: "s" * 2001, children_at_home: "", notes: "" },
      headers: bearer(token), as: :json
    assert_stage_error "When someone here needs help, who steps in? is too long", "who_steps_in" => [ "is too long" ]
    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: "", who_steps_in: "", children_at_home: "", notes: "n" * 2001 },
      headers: bearer(token), as: :json
    assert_stage_error "Anything else they said is too long", "notes" => [ "is too long" ]
    assert_equal kept, enrolment.verification.reload.dynamics
    assert_equal who_saved, enrolment.verification.who_is_here
    assert_equal formation, enrolment.verification.formation

    added = who_is_here_body(enrolment)
    added[:people] << added_person.merge(relationship: "child")
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: added, headers: bearer(token), as: :json
    assert_response :ok
    put "/enrolments/#{enrolment.id}/verification/dynamics",
      params: { hard_week: "", who_steps_in: "", children_at_home: " The added child ", notes: "" },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "The added child", response.parsed_body["children_at_home"]
    dynamics = enrolment.verification.reload.dynamics
    who_saved = enrolment.verification.who_is_here

    put "/enrolments/#{enrolment.id}/verification/formation",
      params: { started_year: 2008, how_it_started: "Later", notes: "" },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal 2008, response.parsed_body["started_year"]
    assert_equal who_saved, enrolment.verification.reload.who_is_here
    assert_equal dynamics, enrolment.verification.dynamics

    put "/enrolments/#{enrolment.id}/verification/formation",
      params: { started_year: 2008, how_it_started: "h" * 2001, notes: "" },
      headers: bearer(token), as: :json
    assert_stage_error "How did it start? is too long", "how_it_started" => [ "is too long" ]
    assert_equal who_saved, enrolment.verification.reload.who_is_here
    assert_equal dynamics, enrolment.verification.dynamics
    assert_equal 2008, enrolment.verification.formation["started_year"]

    get "/enrolments/#{enrolment.id}", headers: bearer(token)
    assert_response :ok
    detail = response.parsed_body.fetch("verification")
    assert_equal enrolment.verification.formation, detail["formation"]
    assert_equal enrolment.verification.dynamics, detail["dynamics"]
    assert_nil detail["daily_life"]
    assert_nil detail["house"]
    assert_nil detail["needs"]
    assert_nil detail["boxes"]
  end

  test "a day in their life stores working and school independently" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    who = who_is_here_body(enrolment)
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: who, headers: bearer(token), as: :json
    assert_response :ok
    who_saved = enrolment.verification.reload.who_is_here

    assert_no_enqueued_emails do
      put "/enrolments/#{enrolment.id}/verification/daily_life",
        params: { people: [] }, headers: bearer(token), as: :json
    end
    assert_response :ok
    assert_equal [], response.parsed_body["people"]
    assert_equal "", response.parsed_body["notes"]
    assert_equal who_saved, enrolment.verification.reload.who_is_here

    person_id = SecureRandom.uuid
    both = {
      person_id: person_id,
      working: true,
      job: " Tailor ",
      monthly_amount: 800,
      previous_jobs: " Sewing ",
      wished_work: " A shop ",
      skills: " Patterns ",
      in_school: true,
      school_going: " Well ",
      school_where: " Kampung school ",
      school_travel: " Walk "
    }
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ both ], wealth: "hidden" }, headers: bearer(token), as: :json
    assert_response :ok
    saved = response.parsed_body["people"].sole
    assert_equal "Tailor", saved["job"]
    assert_equal 800, saved["monthly_amount"]
    assert_equal "Sewing", saved["previous_jobs"]
    assert_equal "A shop", saved["wished_work"]
    assert_equal "Patterns", saved["skills"]
    assert_equal "Well", saved["school_going"]
    assert_equal "Kampung school", saved["school_where"]
    assert_equal "Walk", saved["school_travel"]
    assert_not response.parsed_body.key?("wealth")
    assert_equal who_saved, enrolment.verification.reload.who_is_here

    closed = both.merge(
      working: false,
      in_school: nil,
      job: "x" * 201,
      monthly_amount: "nope",
      previous_jobs: "p" * 2001,
      wished_work: 12,
      school_going: "s" * 2001,
      school_where: "w" * 201,
      school_travel: false,
      skills: "Still here"
    )
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ closed ] }, headers: bearer(token), as: :json
    assert_response :ok
    cleared = response.parsed_body["people"].sole
    assert_equal false, cleared["working"]
    assert_nil cleared["in_school"]
    assert_equal "", cleared["job"]
    assert_nil cleared["monthly_amount"]
    assert_equal "", cleared["previous_jobs"]
    assert_equal "", cleared["wished_work"]
    assert_equal "", cleared["school_going"]
    assert_equal "", cleared["school_where"]
    assert_equal "", cleared["school_travel"]
    assert_equal "Still here", cleared["skills"]

    limits = both.merge(job: "j" * 200, school_where: "s" * 200, previous_jobs: "p" * 2000, skills: "k" * 2000, monthly_amount: 999_999_999)
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ limits ] }, headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "j" * 200, response.parsed_body["people"].sole["job"]
    assert_equal "s" * 200, response.parsed_body["people"].sole["school_where"]
    assert_equal "p" * 2000, response.parsed_body["people"].sole["previous_jobs"]
    assert_equal "k" * 2000, response.parsed_body["people"].sole["skills"]
    assert_equal 999_999_999, response.parsed_body["people"].sole["monthly_amount"]

    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ both.merge(monthly_amount: 0) ] }, headers: bearer(token), as: :json
    assert_response :ok
    assert_equal 0, response.parsed_body["people"].sole["monthly_amount"]
    stored = enrolment.verification.reload.daily_life

    [
      [ { monthly_amount: "800" }, "Ringgit per month is invalid", "monthly_amount", "is invalid" ],
      [ { monthly_amount: 1.5 }, "Ringgit per month is invalid", "monthly_amount", "is invalid" ],
      [ { monthly_amount: -1 }, "Ringgit per month is invalid", "monthly_amount", "is invalid" ],
      [ { monthly_amount: 1_000_000_000 }, "Ringgit per month is invalid", "monthly_amount", "is invalid" ],
      [ { job: "j" * 201 }, "What job? is too long", "job", "is too long" ],
      [ { school_where: "s" * 201 }, "Where is school? is too long", "school_where", "is too long" ],
      [ { previous_jobs: "p" * 2001 }, "Any previous jobs? is too long", "previous_jobs", "is too long" ],
      [ { skills: "k" * 2001 }, "Any skills to highlight? is too long", "skills", "is too long" ],
      [ { working: "yes" }, "Are you working? is invalid", "working", "is invalid" ]
    ].each do |override, message, field, detail|
      put "/enrolments/#{enrolment.id}/verification/daily_life",
        params: { people: [ both.merge(override) ] }, headers: bearer(token), as: :json
      assert_stage_error message, field => [ detail ]
    end
    assert_equal stored, enrolment.verification.reload.daily_life
    assert_equal who_saved, enrolment.verification.who_is_here
    assert_nil enrolment.verification.formation
  end

  test "a day in their life keeps each side, every person, and a blank answer" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    first = SecureRandom.uuid
    second = SecureRandom.uuid
    travel_to Time.utc(2026, 11, 18, 5, 0, 0) do
      put "/enrolments/#{enrolment.id}/verification/daily_life",
        params: {
          people: [
            { person_id: first, working: true, in_school: true, job: "", monthly_amount: nil, skills: nil },
            { person_id: second, working: true, in_school: false, job: "Cook", monthly_amount: 0, skills: "Knives" }
          ],
          worker_name: "Hacker",
          recorded_at: "1999-01-01T00:00:00Z"
        },
        headers: bearer(token), as: :json
    end
    assert_response :ok
    body = response.parsed_body
    assert_equal "Aman", body["worker_name"]
    assert_equal "2026-11-18T05:00:00Z", body["recorded_at"]
    assert_equal [ first, second ], body["people"].map { |person| person["person_id"] }
    assert_equal true, body["people"][0]["working"]
    assert_equal true, body["people"][0]["in_school"]
    assert_equal "", body["people"][0]["job"]
    assert_nil body["people"][0]["monthly_amount"]
    assert_equal "", body["people"][0]["skills"]
    assert_equal "", body["people"][0]["school_going"]

    work_only = {
      person_id: first, working: true, in_school: false, job: "Cook", monthly_amount: 40,
      skills: "Knives", school_where: "s" * 201, school_travel: false, school_going: "x" * 2001
    }
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ work_only ] }, headers: bearer(token), as: :json
    assert_response :ok
    saved = response.parsed_body["people"].sole
    assert_equal "Cook", saved["job"]
    assert_equal 40, saved["monthly_amount"]
    assert_equal "Knives", saved["skills"]
    assert_equal "", saved["school_going"]
    assert_equal "", saved["school_where"]
    assert_equal "", saved["school_travel"]

    school_only = {
      person_id: first, working: nil, in_school: true, job: "j" * 201, monthly_amount: "800",
      skills: "Still", school_going: "Well", school_where: "Here", school_travel: "Bus"
    }
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ school_only ] }, headers: bearer(token), as: :json
    assert_response :ok
    saved = response.parsed_body["people"].sole
    assert_nil saved["working"]
    assert_equal "", saved["job"]
    assert_nil saved["monthly_amount"]
    assert_equal "Still", saved["skills"]
    assert_equal "Well", saved["school_going"]
    assert_equal "Here", saved["school_where"]
    assert_equal "Bus", saved["school_travel"]
    column = enrolment.verification.reload.daily_life

    long = {
      person_id: first, working: true, in_school: true, skills: "",
      wished_work: "w" * 2000, school_going: "g" * 2000, school_travel: "t" * 2000,
      school_where: "s" * 200, previous_jobs: "p" * 2000
    }
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ long ] }, headers: bearer(token), as: :json
    assert_response :ok
    saved = response.parsed_body["people"].sole
    assert_equal "w" * 2000, saved["wished_work"]
    assert_equal "g" * 2000, saved["school_going"]
    assert_equal "t" * 2000, saved["school_travel"]
    assert_equal "s" * 200, saved["school_where"]
    assert_equal "p" * 2000, saved["previous_jobs"]
    column = enrolment.verification.reload.daily_life

    [
      [ { wished_work: "w" * 2001 }, "If you wish for a new job or income, what would that be? is too long", "wished_work" ],
      [ { school_going: "g" * 2001 }, "How is school going? is too long", "school_going" ],
      [ { school_travel: "t" * 2001 }, "How do you get there? is too long", "school_travel" ]
    ].each do |override, message, field|
      put "/enrolments/#{enrolment.id}/verification/daily_life",
        params: { people: [ long.merge(override) ] }, headers: bearer(token), as: :json
      assert_stage_error message, field => [ "is too long" ]
    end

    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ long.merge(job: "j" * 201, monthly_amount: "800", school_where: "s" * 201) ] },
      headers: bearer(token), as: :json
    assert_stage_error "What job? is too long",
      "job" => [ "is too long" ],
      "monthly_amount" => [ "is invalid" ],
      "school_where" => [ "is too long" ]

    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ long.merge(job: 12) ] }, headers: bearer(token), as: :json
    assert_stage_error "What job? is invalid", "job" => [ "is invalid" ]
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ long.merge(school_going: 12) ] }, headers: bearer(token), as: :json
    assert_stage_error "How is school going? is invalid", "school_going" => [ "is invalid" ]
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ long.merge(skills: 12) ] }, headers: bearer(token), as: :json
    assert_stage_error "Any skills to highlight? is invalid", "skills" => [ "is invalid" ]
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ long.merge(in_school: "yes") ] }, headers: bearer(token), as: :json
    assert_stage_error "Are you in school? is invalid", "in_school" => [ "is invalid" ]

    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ long.merge(job: " #{'j' * 200} ") ] }, headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "j" * 200, response.parsed_body["people"].sole["job"]
    column = enrolment.verification.reload.daily_life
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ long.merge(job: " #{'j' * 201} ") ] }, headers: bearer(token), as: :json
    assert_stage_error "What job? is too long", "job" => [ "is too long" ]

    neither = { person_id: first, working: false, in_school: false, skills: "k" * 2000, job: "j" * 201 }
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ neither ] }, headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "k" * 2000, response.parsed_body["people"].sole["skills"]
    assert_equal "", response.parsed_body["people"].sole["job"]
    column = enrolment.verification.reload.daily_life
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ neither.merge(skills: "k" * 2001) ] }, headers: bearer(token), as: :json
    assert_stage_error "Any skills to highlight? is too long", "skills" => [ "is too long" ]

    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: {}, headers: bearer(token), as: :json
    assert_stage_error "Person is invalid", "person_id" => [ "is invalid" ]
    [
      { people: "nope" },
      { people: [ "nope", long ] },
      { people: [ long.merge(person_id: "nope") ] },
      { people: [ long, long.merge(person_id: first) ] }
    ].each do |params|
      put "/enrolments/#{enrolment.id}/verification/daily_life",
        params: params, headers: bearer(token), as: :json
      assert_stage_error "Person is invalid", "person_id" => [ "is invalid" ]
    end
    assert_equal column, enrolment.verification.reload.daily_life

    noted = { person_id: first, working: false, in_school: false, skills: "" }
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ noted ], notes: " #{'n' * 2000} " }, headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "n" * 2000, response.parsed_body["notes"]
    column = enrolment.verification.reload.daily_life
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ noted ], notes: "n" * 2001 }, headers: bearer(token), as: :json
    assert_stage_error "Anything else they said is too long", "notes" => [ "is too long" ]
    put "/enrolments/#{enrolment.id}/verification/daily_life",
      params: { people: [ noted ], notes: 12 }, headers: bearer(token), as: :json
    assert_stage_error "Anything else they said is invalid", "notes" => [ "is invalid" ]
    assert_equal column, enrolment.verification.reload.daily_life
  end

  test "the house stores rent and an unsafe place only when those answers open" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    who = who_is_here_body(enrolment)
    put "/enrolments/#{enrolment.id}/verification/who_is_here",
      params: who, headers: bearer(token), as: :json
    assert_response :ok
    who_saved = enrolment.verification.reload.who_is_here

    blank = {
      place: "", has_water: nil, has_electricity: nil, sleeping_rooms: nil,
      safe: nil, meals: "", basket: "", notes: ""
    }
    put "/enrolments/#{enrolment.id}/verification/house",
      params: blank, headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "", response.parsed_body["place"]
    assert_nil response.parsed_body["rent_per_month"]
    assert_nil response.parsed_body["behind_on_payments"]
    assert_equal "", response.parsed_body["unsafe_detail"]
    assert_equal who_saved, enrolment.verification.reload.who_is_here

    rent = blank.merge(
      place: "rent", rent_per_month: 500, behind_on_payments: true,
      has_water: true, has_electricity: false, sleeping_rooms: 2,
      safe: false, unsafe_detail: " The stairs ", meals: "two", basket: " Rice ", notes: " Quiet "
    )
    put "/enrolments/#{enrolment.id}/verification/house",
      params: rent, headers: bearer(token), as: :json
    assert_response :ok
    saved = response.parsed_body
    assert_equal "rent", saved["place"]
    assert_equal 500, saved["rent_per_month"]
    assert_equal true, saved["behind_on_payments"]
    assert_equal true, saved["has_water"]
    assert_equal false, saved["has_electricity"]
    assert_equal 2, saved["sleeping_rooms"]
    assert_equal "two", saved["meals"]
    assert_equal "The stairs", saved["unsafe_detail"]
    assert_equal "Rice", saved["basket"]
    assert_equal "Quiet", saved["notes"]

    closed = rent.merge(place: "own", safe: true, rent_per_month: "nope", behind_on_payments: "yes", unsafe_detail: "x" * 2001)
    put "/enrolments/#{enrolment.id}/verification/house",
      params: closed, headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "own", response.parsed_body["place"]
    assert_nil response.parsed_body["rent_per_month"]
    assert_nil response.parsed_body["behind_on_payments"]
    assert_equal "", response.parsed_body["unsafe_detail"]
    stored = enrolment.verification.reload.house

    [
      [ { place: "palace" }, "This place is invalid", "place", "is invalid" ],
      [ { meals: "five" }, "How many meals a day? is invalid", "meals", "is invalid" ],
      [ { sleeping_rooms: "2" }, "How many rooms do people sleep in? is invalid", "sleeping_rooms", "is invalid" ],
      [ { sleeping_rooms: 1.5 }, "How many rooms do people sleep in? is invalid", "sleeping_rooms", "is invalid" ],
      [ { sleeping_rooms: 100 }, "How many rooms do people sleep in? is invalid", "sleeping_rooms", "is invalid" ],
      [ { rent_per_month: -1 }, "Rent per month is invalid", "rent_per_month", "is invalid" ],
      [ { has_water: "yes" }, "Does it have water? is invalid", "has_water", "is invalid" ],
      [ { basket: "b" * 501 }, "Basket is too long", "basket", "is too long" ]
    ].each do |override, message, field, detail|
      put "/enrolments/#{enrolment.id}/verification/house",
        params: rent.merge(override), headers: bearer(token), as: :json
      assert_stage_error message, field => [ detail ]
    end
    assert_equal stored, enrolment.verification.reload.house
    assert_equal who_saved, enrolment.verification.who_is_here

    put "/enrolments/#{enrolment.id}/verification/house",
      params: rent.merge(sleeping_rooms: 0, rent_per_month: 999_999_999, basket: "b" * 500),
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal 0, response.parsed_body["sleeping_rooms"]
    assert_equal 999_999_999, response.parsed_body["rent_per_month"]
    assert_equal "b" * 500, response.parsed_body["basket"]
  end

  test "a closed house follow-up stays empty even when the answer would be valid" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    base = {
      place: "own", has_water: nil, has_electricity: nil, sleeping_rooms: nil,
      safe: nil, meals: "", basket: "", notes: ""
    }

    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(rent_per_month: 500, behind_on_payments: true),
      headers: bearer(token), as: :json
    assert_response :ok
    assert_nil response.parsed_body["rent_per_month"]
    assert_nil response.parsed_body["behind_on_payments"]

    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(
        place: "staying_with_someone", safe: false, unsafe_detail: " The roof ", meals: "three",
        rent_per_month: "nope", behind_on_payments: "yes"
      ),
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "staying_with_someone", response.parsed_body["place"]
    assert_nil response.parsed_body["rent_per_month"]
    assert_nil response.parsed_body["behind_on_payments"]
    assert_equal "The roof", response.parsed_body["unsafe_detail"]
    assert_equal "three", response.parsed_body["meals"]

    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(
        place: "temporary", safe: nil, unsafe_detail: "u" * 2001, meals: "not_every_day",
        rent_per_month: "nope", behind_on_payments: "yes"
      ),
      headers: bearer(token), as: :json
    assert_response :ok
    assert_nil response.parsed_body["rent_per_month"]
    assert_equal "", response.parsed_body["unsafe_detail"]
    assert_equal "not_every_day", response.parsed_body["meals"]

    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(safe: true, unsafe_detail: "The roof"),
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "", response.parsed_body["unsafe_detail"]
    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(safe: nil, unsafe_detail: "The roof"),
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "", response.parsed_body["unsafe_detail"]

    travel_to Time.utc(2026, 11, 18, 6, 0, 0) do
      put "/enrolments/#{enrolment.id}/verification/house",
        params: base.merge(
          place: "rent", rent_per_month: 500, behind_on_payments: false, safe: true,
          unsafe_detail: "u" * 2001, meals: "one", worker_name: "Hacker",
          recorded_at: "1999-01-01T00:00:00Z", wealth: "hidden"
        ),
        headers: bearer(token), as: :json
    end
    assert_response :ok
    assert_equal 500, response.parsed_body["rent_per_month"]
    assert_equal false, response.parsed_body["behind_on_payments"]
    assert_equal "", response.parsed_body["unsafe_detail"]
    assert_equal "one", response.parsed_body["meals"]
    assert_equal "Aman", response.parsed_body["worker_name"]
    assert_equal "2026-11-18T06:00:00Z", response.parsed_body["recorded_at"]
    assert_not response.parsed_body.key?("wealth")
    stored = enrolment.verification.reload.house

    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(place: "rent", behind_on_payments: "yes"),
      headers: bearer(token), as: :json
    assert_stage_error "Are you behind on payments? is invalid", "behind_on_payments" => [ "is invalid" ]

    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(place: "rent", rent_per_month: nil, behind_on_payments: nil),
      headers: bearer(token), as: :json
    assert_response :ok
    assert_nil response.parsed_body["rent_per_month"]
    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(place: "rent", rent_per_month: 0, behind_on_payments: false, sleeping_rooms: 99),
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal 0, response.parsed_body["rent_per_month"]
    assert_equal 99, response.parsed_body["sleeping_rooms"]
    stored = enrolment.verification.reload.house

    [
      [ "8", "Rent per month is invalid", "rent_per_month" ],
      [ 1.0, "Rent per month is invalid", "rent_per_month" ],
      [ 1_000_000_000, "Rent per month is invalid", "rent_per_month" ]
    ].each do |amount, message, field|
      put "/enrolments/#{enrolment.id}/verification/house",
        params: base.merge(place: "rent", rent_per_month: amount, behind_on_payments: false),
        headers: bearer(token), as: :json
      assert_stage_error message, field => [ "is invalid" ]
    end

    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(safe: false, unsafe_detail: " #{'u' * 2000} ", notes: " #{'n' * 2000} "),
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "u" * 2000, response.parsed_body["unsafe_detail"]
    assert_equal "n" * 2000, response.parsed_body["notes"]
    stored = enrolment.verification.reload.house
    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(safe: false, unsafe_detail: "u" * 2001),
      headers: bearer(token), as: :json
    assert_stage_error "What feels unsafe? is too long", "unsafe_detail" => [ "is too long" ]
    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(safe: false, unsafe_detail: 12),
      headers: bearer(token), as: :json
    assert_stage_error "What feels unsafe? is invalid", "unsafe_detail" => [ "is invalid" ]
    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(notes: "n" * 2001),
      headers: bearer(token), as: :json
    assert_stage_error "Anything else they said is too long", "notes" => [ "is too long" ]
    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(notes: 12),
      headers: bearer(token), as: :json
    assert_stage_error "Anything else they said is invalid", "notes" => [ "is invalid" ]
    put "/enrolments/#{enrolment.id}/verification/house",
      params: base.merge(place: "palace", meals: "five"),
      headers: bearer(token), as: :json
    assert_stage_error "This place is invalid",
      "place" => [ "is invalid" ],
      "meals" => [ "is invalid" ]
    assert_equal stored, enrolment.verification.reload.house
  end

  test "what they need stores consent and rejects a non-boolean" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    put "/enrolments/#{enrolment.id}/verification/house",
      params: {
        place: "own", has_water: nil, has_electricity: nil, sleeping_rooms: nil,
        safe: nil, meals: "", basket: "", notes: ""
      },
      headers: bearer(token), as: :json
    assert_response :ok
    house = enrolment.verification.reload.house

    put "/enrolments/#{enrolment.id}/verification/needs",
      params: {}, headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "", response.parsed_body["need_most"]
    assert_nil response.parsed_body["consent_given"]
    assert_equal "", response.parsed_body["notes"]

    travel_to Time.utc(2026, 11, 18, 6, 0, 0) do
      put "/enrolments/#{enrolment.id}/verification/needs",
        params: {
          need_most: " School supplies ", consent_given: true, notes: " Quiet ",
          worker_name: "Hacker", recorded_at: "1999-01-01T00:00:00Z", wealth: "hidden"
        },
        headers: bearer(token), as: :json
    end
    assert_response :ok
    assert_equal "School supplies", response.parsed_body["need_most"]
    assert_equal true, response.parsed_body["consent_given"]
    assert_equal "Quiet", response.parsed_body["notes"]
    assert_equal "Aman", response.parsed_body["worker_name"]
    assert_equal "2026-11-18T06:00:00Z", response.parsed_body["recorded_at"]
    assert_not response.parsed_body.key?("wealth")
    assert_no_enqueued_jobs
    assert_equal house, enrolment.verification.reload.house

    put "/enrolments/#{enrolment.id}/verification/needs",
      params: { need_most: "", consent_given: false, notes: "" },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal false, response.parsed_body["consent_given"]
    put "/enrolments/#{enrolment.id}/verification/needs",
      params: { consent_given: nil },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_nil response.parsed_body["consent_given"]
    stored = enrolment.verification.reload.needs

    [
      [ "yes", "Consent is invalid" ],
      [ 1, "Consent is invalid" ],
      [ [ false ], "Consent is invalid" ]
    ].each do |value, message|
      put "/enrolments/#{enrolment.id}/verification/needs",
        params: { consent_given: value },
        headers: bearer(token), as: :json
      assert_stage_error message, "consent_given" => [ "is invalid" ]
    end

    put "/enrolments/#{enrolment.id}/verification/needs",
      params: { need_most: " #{'n' * 2000} ", notes: " #{'m' * 2000} ", consent_given: true },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "n" * 2000, response.parsed_body["need_most"]
    assert_equal "m" * 2000, response.parsed_body["notes"]
    stored = enrolment.verification.reload.needs

    put "/enrolments/#{enrolment.id}/verification/needs",
      params: { need_most: "n" * 2001, consent_given: "yes", notes: 12 },
      headers: bearer(token), as: :json
    assert_stage_error "What do you need most? is too long",
      "need_most" => [ "is too long" ],
      "consent_given" => [ "is invalid" ],
      "notes" => [ "is invalid" ]
    put "/enrolments/#{enrolment.id}/verification/needs",
      params: { need_most: 12 },
      headers: bearer(token), as: :json
    assert_stage_error "What do you need most? is invalid", "need_most" => [ "is invalid" ]
    put "/enrolments/#{enrolment.id}/verification/needs",
      params: { notes: "m" * 2001 },
      headers: bearer(token), as: :json
    assert_stage_error "Anything else they said is too long", "notes" => [ "is too long" ]
    assert_equal stored, enrolment.verification.reload.needs
    assert_equal house, enrolment.verification.reload.house
  end

  test "post-visit stores both boxes and both gaps" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    put "/enrolments/#{enrolment.id}/verification/needs",
      params: { need_most: "", consent_given: false, notes: "" },
      headers: bearer(token), as: :json
    assert_response :ok
    needs = enrolment.verification.reload.needs

    put "/enrolments/#{enrolment.id}/verification/boxes",
      params: {}, headers: bearer(token), as: :json
    assert_response :ok
    assert_nil response.parsed_body["good_family_unit"]
    assert_equal "", response.parsed_body["good_family_unit_gap"]
    assert_nil response.parsed_body["basic_necessities"]
    assert_equal "", response.parsed_body["basic_necessities_gap"]
    assert_equal "", response.parsed_body["notes"]

    travel_to Time.utc(2026, 11, 18, 6, 0, 0) do
      put "/enrolments/#{enrolment.id}/verification/boxes",
        params: {
          good_family_unit: false, good_family_unit_gap: " The father is away ",
          basic_necessities: false, basic_necessities_gap: "   ",
          notes: " Quiet ", dependable_generation: true, accumulated_wealth: "hidden",
          worker_name: "Hacker", recorded_at: "1999-01-01T00:00:00Z"
        },
        headers: bearer(token), as: :json
    end
    assert_response :ok
    assert_equal false, response.parsed_body["good_family_unit"]
    assert_equal "The father is away", response.parsed_body["good_family_unit_gap"]
    assert_equal false, response.parsed_body["basic_necessities"]
    assert_equal "", response.parsed_body["basic_necessities_gap"]
    assert_equal "Quiet", response.parsed_body["notes"]
    assert_equal "Aman", response.parsed_body["worker_name"]
    assert_equal "2026-11-18T06:00:00Z", response.parsed_body["recorded_at"]
    assert_not response.parsed_body.key?("dependable_generation")
    assert_not response.parsed_body.key?("accumulated_wealth")
    assert_equal needs, enrolment.verification.reload.needs

    put "/enrolments/#{enrolment.id}/verification/boxes",
      params: {
        good_family_unit: true, good_family_unit_gap: "still written",
        basic_necessities: nil, basic_necessities_gap: ""
      },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal true, response.parsed_body["good_family_unit"]
    assert_equal "still written", response.parsed_body["good_family_unit_gap"]
    assert_nil response.parsed_body["basic_necessities"]
    stored = enrolment.verification.reload.boxes

    [
      [ { good_family_unit: "yes" }, "Good family unit is invalid", "good_family_unit" ],
      [ { good_family_unit: "true" }, "Good family unit is invalid", "good_family_unit" ],
      [ { good_family_unit: "false" }, "Good family unit is invalid", "good_family_unit" ],
      [ { good_family_unit: 1 }, "Good family unit is invalid", "good_family_unit" ],
      [ { basic_necessities: "yes" }, "Basic necessities is invalid", "basic_necessities" ],
      [ { basic_necessities: [ false ] }, "Basic necessities is invalid", "basic_necessities" ]
    ].each do |extra, message, field|
      put "/enrolments/#{enrolment.id}/verification/boxes",
        params: extra, headers: bearer(token), as: :json
      assert_stage_error message, field => [ "is invalid" ]
    end
    assert_equal stored, enrolment.verification.reload.boxes

    put "/enrolments/#{enrolment.id}/verification/boxes",
      params: {
        good_family_unit: false, good_family_unit_gap: " #{'g' * 2000} ",
        basic_necessities: true, basic_necessities_gap: " #{'b' * 2000} ",
        notes: " #{'n' * 2000} "
      },
      headers: bearer(token), as: :json
    assert_response :ok
    assert_equal "g" * 2000, response.parsed_body["good_family_unit_gap"]
    assert_equal "b" * 2000, response.parsed_body["basic_necessities_gap"]
    assert_equal "n" * 2000, response.parsed_body["notes"]
    stored = enrolment.verification.reload.boxes

    put "/enrolments/#{enrolment.id}/verification/boxes",
      params: { good_family_unit_gap: "g" * 2001, basic_necessities_gap: 12, notes: "n" * 2001 },
      headers: bearer(token), as: :json
    assert_stage_error "Gap is too long",
      "good_family_unit_gap" => [ "is too long" ],
      "basic_necessities_gap" => [ "is invalid" ],
      "notes" => [ "is too long" ]
    put "/enrolments/#{enrolment.id}/verification/boxes",
      params: { good_family_unit: "yes", basic_necessities: "yes" },
      headers: bearer(token), as: :json
    assert_stage_error "Good family unit is invalid",
      "good_family_unit" => [ "is invalid" ],
      "basic_necessities" => [ "is invalid" ]
    assert_equal stored, enrolment.verification.reload.boxes
    assert_equal needs, enrolment.verification.reload.needs
  end

  test "a complete visit is marked once and then locked" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    save_interview(enrolment, token, consent: true, head_identity: "not_verified", spouse_identity: "no_papers")

    travel_to Time.utc(2026, 11, 18, 6, 0, 0) do
      post "/enrolments/#{enrolment.id}/qualification",
        params: { outcome: "qualified" }, headers: bearer(token), as: :json
    end
    assert_response :created
    assert_equal(
      { "outcome" => "qualified", "marked_at" => "2026-11-18T06:00:00Z", "marker_name" => "Aman" },
      response.parsed_body
    )
    assert_enqueued_emails 1
    clear_enqueued_jobs

    post "/enrolments/#{enrolment.id}/qualification", params: {}, headers: bearer(token), as: :json
    assert_stage_error "Outcome is required", "outcome" => [ "is required" ]
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "wealth" }, headers: bearer(token), as: :json
    assert_stage_error "Outcome is invalid", "outcome" => [ "is invalid" ]
    assert_equal "qualified", enrolment.reload.outcome
    assert_equal Time.utc(2026, 11, 18, 6, 0, 0), enrolment.marked_at
    assert_no_enqueued_jobs

    travel_to Time.utc(2026, 11, 18, 7, 0, 0) do
      post "/enrolments/#{enrolment.id}/qualification",
        params: { outcome: "disqualified" }, headers: bearer(token), as: :json
    end
    assert_stage_error "The mark is already set", "outcome" => [ "is already set" ]
    assert_equal "qualified", enrolment.reload.outcome
    assert_equal Time.utc(2026, 11, 18, 6, 0, 0), enrolment.marked_at
    assert_no_enqueued_jobs

    patch "/enrolments/#{enrolment.id}/visit",
      params: { visit_at: "", bringing_basket: true, assigned_workers: [ "Aman" ] },
      headers: bearer(token), as: :json
    assert_stage_error "Verification is finished", {}
    assert_equal Time.utc(2026, 11, 24, 1, 0, 0), enrolment.reload.visit_at
    put "/enrolments/#{enrolment.id}/verification/house",
      params: { basket: "Changed" }, headers: bearer(token), as: :json
    assert_stage_error "Verification is finished", {}
    assert_equal "Rice", enrolment.verification.reload.house["basket"]
    assert_no_enqueued_jobs

    get "/enrolments/#{enrolment.id}", headers: bearer(token)
    assert_response :ok
    detail = response.parsed_body
    assert_equal "qualified", detail["outcome"]
    assert_equal "2026-11-18T06:00:00Z", detail["marked_at"]
    assert_equal "Aman", detail["marker_name"]

    get "/enrolments", headers: bearer(token)
    row = response.parsed_body.find { |item| item["id"] == enrolment.id }
    assert_equal "qualified", row["outcome"]
    assert_not row.key?("marked_at")
    assert_not row.key?("marker_name")
    assert_not row.key?("verification")

    submitter = confirmed_token(email: "siti@example.com")
    get "/enrolments/#{enrolment.id}", headers: bearer(submitter)
    assert_response :ok
    shown = response.parsed_body
    assert_equal "qualified", shown.dig("progress", "outcome")
    assert_not shown.key?("marked_at")
    assert_not shown.key?("marker_name")
    assert_not shown.key?("verification")
    assert_not shown.key?("bringing_basket")

    post "/enrolments", params: valid_enrolment.merge(email: "aminah@example.com"), as: :json
    assert_response :created
    assert_nil response.parsed_body.dig("progress", "outcome")
  end

  test "a refused consent can be disqualified and cannot be qualified" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    save_interview(enrolment, token, consent: false, boxes_checked: false)
    enrolment.verification.update!(house: enrolment.verification.house.merge("basket" => ""))
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Basket is required", "basket" => [ "is required" ]
    assert_nil enrolment.reload.outcome
    assert_no_enqueued_jobs
    enrolment.verification.update!(house: enrolment.verification.house.merge("basket" => "Rice"))

    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "The family has not consented", "outcome" => [ "needs consent" ]
    assert_nil enrolment.reload.outcome
    assert_no_enqueued_jobs

    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "disqualified" }, headers: bearer(token), as: :json
    assert_response :created
    assert_equal "disqualified", response.parsed_body["outcome"]

    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "The mark is already set", "outcome" => [ "is already set" ]
    assert_equal "disqualified", enrolment.reload.outcome
  end

  test "the mark names the first missing part and the first bad field" do
    enrolment = submit_family
    token = worker_token(name: "Aman", locality: enrolment.locality)
    post "/enrolments/#{enrolment.id}/qualification", params: {}, headers: bearer(token), as: :json
    assert_stage_error "Outcome is required", "outcome" => [ "is required" ]
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "wealth" }, headers: bearer(token), as: :json
    assert_stage_error "Outcome is invalid", "outcome" => [ "is invalid" ]
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Set the visit before recording it", {}
    assert_nil enrolment.reload.outcome

    set_visit(enrolment, token)
    %w[who_is_here formation daily_life dynamics house needs boxes].each do |part|
      post "/enrolments/#{enrolment.id}/qualification",
        params: { outcome: "qualified" }, headers: bearer(token), as: :json
      assert_stage_error "The visit record is incomplete", part => [ "is required" ]
      save_stage(enrolment, token, part, stage_body(enrolment, part))
    end

    blank_basket = enrolment.verification.reload.house.merge("basket" => "")
    enrolment.verification.update!(house: blank_basket)
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Basket is required", "basket" => [ "is required" ]
    enrolment.verification.update!(house: blank_basket.merge("basket" => "b" * 501))
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Basket is too long", "basket" => [ "is too long" ]
    enrolment.verification.update!(house: blank_basket.merge("basket" => "Rice"))

    enrolment.verification.update!(needs: enrolment.verification.needs.merge("consent_given" => nil))
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Consent is required", "consent_given" => [ "is required" ]
    enrolment.verification.update!(needs: enrolment.verification.needs.merge("consent_given" => true))

    people = enrolment.verification.who_is_here["people"]
    people[0]["identity"] = ""
    enrolment.verification.update!(who_is_here: enrolment.verification.who_is_here.merge("people" => people))
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Identity check is required", "identity" => [ "is required" ]
    people[0]["identity"] = "citizen"
    enrolment.verification.update!(who_is_here: enrolment.verification.who_is_here.merge("people" => people))
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Identity check is invalid", "identity" => [ "is invalid" ]
    people[0]["identity"] = "verified"
    people[1]["identity"] = "not_verified"
    people[1]["relationship"] = ""
    enrolment.verification.update!(who_is_here: enrolment.verification.who_is_here.merge("people" => people))
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Relationship is required", "relationship" => [ "is required" ]
    people[1]["relationship"] = "cousin"
    enrolment.verification.update!(who_is_here: enrolment.verification.who_is_here.merge("people" => people))
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Relationship is invalid", "relationship" => [ "is invalid" ]
    people[1]["relationship"] = "spouse"
    enrolment.verification.update!(who_is_here: enrolment.verification.who_is_here.merge("people" => people))

    boxes = enrolment.verification.boxes.merge("good_family_unit" => nil)
    enrolment.verification.update!(boxes: boxes)
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Good family unit is required", "good_family_unit" => [ "is required" ]
    boxes = boxes.merge("good_family_unit" => false, "good_family_unit_gap" => "", "basic_necessities" => nil)
    enrolment.verification.update!(boxes: boxes)
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Basic necessities is required", "basic_necessities" => [ "is required" ]
    boxes = boxes.merge("basic_necessities" => false, "basic_necessities_gap" => "Rent")
    enrolment.verification.update!(boxes: boxes)
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(token), as: :json
    assert_stage_error "Gap is required", "gap" => [ "is required" ]
    boxes = boxes.merge("good_family_unit_gap" => "Away", "basic_necessities_gap" => "")
    enrolment.verification.update!(boxes: boxes)
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "disqualified" }, headers: bearer(token), as: :json
    assert_stage_error "Gap is required", "gap" => [ "is required" ]
    assert_nil enrolment.reload.outcome

    post "/enrolments/#{enrolment.id}/qualification", params: { outcome: "qualified" }, as: :json
    assert_sign_in_required
    submitter = confirmed_token(email: "siti@example.com")
    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "qualified" }, headers: bearer(submitter), as: :json
    assert_not_found
  end

  test "the first mark queues one outcome message" do
    enrolment = submit_family
    add_member(enrolment, name: "Rahim", role: "child") if enrolment.members.none? { |member| member.name == "Rahim" }
    enrolment.update!(family_phone: "+60123456789", enroler_contact: "+60198765432")
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    patch "/enrolments/#{enrolment.id}/visit",
      params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: true, assigned_workers: [ "Farid" ] },
      headers: bearer(token), as: :json
    assert_response :ok
    clear_enqueued_jobs
    save_interview(enrolment, token, consent: true, head_identity: "verified", spouse_identity: "not_verified")
    job_log = StringIO.new
    previous_logger = ActiveJob::Base.logger
    ActiveJob::Base.logger = ActiveSupport::Logger.new(job_log)

    assert_enqueued_emails 1 do
      post "/enrolments/#{enrolment.id}/qualification",
        params: { outcome: "qualified" }, headers: bearer(token), as: :json
    end
    assert_response :created
    assert_enqueued_email_with EnrolmentMailer, :outcome_qualified, args: [
      "siti@example.com", "Siti", "Kampung Baru"
    ]
    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "siti@example.com" ], mail.to
    assert_equal "Sokong verification", mail.subject
    assert_equal "Siti at Kampung Baru is qualified.", mail_text(mail)
    assert_outcome_mail_is_only_the_sentence(mail)
    assert_includes job_log.string, "Enqueued EnrolmentInvitationDeliveryJob"
    assert_not_includes job_log.string, "Siti"
    assert_not_includes job_log.string, "Kampung Baru"
    assert_not_includes job_log.string, "siti@example.com"
    delivered = ActionMailer::Base.deliveries.size

    assert_no_enqueued_emails do
      post "/enrolments/#{enrolment.id}/qualification",
        params: { outcome: "disqualified" }, headers: bearer(token), as: :json
    end
    assert_stage_error "The mark is already set", "outcome" => [ "is already set" ]
    perform_enqueued_jobs
    assert_equal delivered, ActionMailer::Base.deliveries.size
  ensure
    ActiveJob::Base.logger = previous_logger
  end

  test "a disqualified mark names that outcome" do
    enrolment = submit_family
    enrolment.update!(family_phone: "+60123456789", enroler_contact: "+60198765432")
    token = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, token)
    clear_enqueued_jobs
    save_interview(enrolment, token, consent: false, boxes_checked: false)
    ActionMailer::Base.deliveries.clear

    assert_enqueued_emails 1 do
      post "/enrolments/#{enrolment.id}/qualification",
        params: { outcome: "disqualified" }, headers: bearer(token), as: :json
    end
    assert_response :created
    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Sokong verification", mail.subject
    assert_equal "Siti at Kampung Baru is disqualified.", mail_text(mail)
    assert_outcome_mail_is_only_the_sentence(mail)
  end

  test "a blank email and a raised outcome enqueue still save the mark" do
    blank = submit_family
    blank.update!(email: "")
    token = worker_token(name: "Aman", locality: blank.locality)
    set_visit(blank, token)
    save_interview(blank, token, consent: true)
    assert_no_enqueued_emails do
      post "/enrolments/#{blank.id}/qualification",
        params: { outcome: "qualified" }, headers: bearer(token), as: :json
    end
    assert_response :created
    assert_equal "qualified", blank.reload.outcome

    enrolment = submit_family
    linked = worker_token(name: "Aman", locality: enrolment.locality)
    set_visit(enrolment, linked)
    save_interview(enrolment, linked, consent: true)
    clear_enqueued_jobs
    previous = ActiveJob::Base.queue_adapter
    adapter = RaisingQueueAdapter.new
    ActiveJob::Base.queue_adapter = adapter
    log = StringIO.new
    logger = ActiveSupport::Logger.new(log)
    previous_logger = ActionController::API.logger
    ActionController::API.logger = logger
    ActionController::Base.logger = logger

    post "/enrolments/#{enrolment.id}/qualification",
      params: { outcome: "disqualified" }, headers: bearer(linked), as: :json

    assert_response :created
    assert_equal 1, adapter.attempts
    assert_equal "disqualified", enrolment.reload.outcome
    assert_includes log.string, "RuntimeError"
    assert_not_includes log.string, "Siti"
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

    def assert_outcome_mail_is_only_the_sentence(mail)
      text = mail.body.to_s
      assert_not_includes text, "Rahim"
      assert_not_includes text, "+60123456789"
      assert_not_includes text, "+60198765432"
      assert_not_includes text, "Farid"
      assert_not_includes text, "Rice"
      assert_not_includes text, "verified"
      assert_not_includes text, "not_verified"
      assert_not_includes text, "true"
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

    def assert_stage_error(message, details)
      assert_response :unprocessable_content
      error = response.parsed_body.fetch("error")
      assert_equal "VALIDATION_ERROR", error["code"]
      assert_equal message, error["message"]
      assert_equal details, error["details"]
    end

    def submit_family
      post "/enrolments", params: valid_enrolment.merge(
        email: "siti@example.com",
        members: [
          { role: "head", name: "Siti", gender: "female" },
          { role: "member", name: "Rahim", gender: "male" }
        ]
      ), as: :json
      assert_response :created
      Enrolment.order(:created_at).last
    end

    def set_visit(enrolment, token)
      patch "/enrolments/#{enrolment.id}/visit",
        params: { visit_at: "2026-11-24T01:00:00Z", bringing_basket: false, assigned_workers: [ "Aman" ] },
        headers: bearer(token),
        as: :json
      assert_response :ok
      clear_enqueued_jobs
    end

    def save_stage(enrolment, token, stage, body)
      put "/enrolments/#{enrolment.id}/verification/#{stage}",
        params: body, headers: bearer(token), as: :json
      assert_response :ok
    end

    def save_interview(enrolment, token, consent:, head_identity: "verified", spouse_identity: "verified", boxes_checked: true)
      body = who_is_here_body(enrolment)
      body[:people][0][:identity] = head_identity
      body[:people][1][:identity] = spouse_identity
      save_stage(enrolment, token, "who_is_here", body)
      %w[formation daily_life dynamics house needs].each do |stage|
        save_stage(enrolment, token, stage, stage_body(enrolment, stage, consent:))
      end
      gap = boxes_checked ? "" : "The father is away"
      save_stage(enrolment, token, "boxes", {
        good_family_unit: boxes_checked, good_family_unit_gap: gap,
        basic_necessities: boxes_checked, basic_necessities_gap: gap, notes: ""
      })
    end

    def stage_body(enrolment, stage, consent: true)
      case stage
      when "who_is_here" then who_is_here_body(enrolment)
      when "formation" then { started_year: nil, how_it_started: "", notes: "" }
      when "daily_life" then { people: [], notes: "" }
      when "dynamics" then { hard_week: "", who_steps_in: "", children_at_home: "", notes: "" }
      when "house"
        {
          place: "own", rent_per_month: nil, behind_on_payments: nil, has_water: nil,
          has_electricity: nil, sleeping_rooms: nil, safe: nil, meals: "", basket: "Rice", notes: ""
        }
      when "needs" then { need_most: "", consent_given: consent, notes: "" }
      when "boxes"
        {
          good_family_unit: true, good_family_unit_gap: "",
          basic_necessities: true, basic_necessities_gap: "", notes: ""
        }
      end
    end

    def who_is_here_body(enrolment)
      head = enrolment.members.find { |member| member.role == "head" }
      child = enrolment.members.find { |member| member.role == "member" }
      {
        people: [ person_for(head), person_for(child, relationship: "spouse", origin: "Kedah") ],
        others_stay: nil,
        others_stay_detail: "",
        care_for_parents: nil,
        care_for_parents_detail: "",
        notes: ""
      }
    end

    def person_for(member, **overrides)
      head = member.role == "head"
      {
        person_id: SecureRandom.uuid,
        family_member_id: member.id,
        head: head,
        name: member.name,
        birth_date: "",
        gender: "",
        phone: "",
        documents: [],
        origin: "",
        relationship: head ? "" : "spouse",
        identity: "",
        absent: false,
        absent_since: "",
        absent_reason: ""
      }.merge(overrides)
    end

    def added_person
      {
        person_id: SecureRandom.uuid,
        family_member_id: nil,
        head: false,
        name: "Guest",
        birth_date: "",
        gender: "",
        phone: "",
        documents: [],
        origin: "Johor",
        relationship: "other",
        identity: "no_papers",
        absent: false,
        absent_since: "2020-01-01",
        absent_reason: "Away"
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
