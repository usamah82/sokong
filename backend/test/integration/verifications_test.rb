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
