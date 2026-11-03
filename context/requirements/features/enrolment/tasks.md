# Tasks

Ordered by dependency. Each task is one session. Checkboxes live here. Decisions and the dependency graph are in [plan.md](plan.md). The contract is [spec.md](spec.md). The phone pictures are [design.md](design.md).

A `Checkpoint` is a review gate. Check it after the tasks above it. Do not open a pull request for a checkpoint.

A task is done only when its acceptance lines are true and [definition of done](../../../workflow/definition-of-done.md) is met. Until Task 14, `bin/ci` is the Rails gate. From Task 14 on, `bin/ci` also runs the web test and lint scripts.

## Task 1: Locality claim

**Description:** Introduce string UUID primary keys and the locality fit rule. `Locality.claim(place_name:, point:)` returns the locality the spec would assign, or creates one when nothing fits. No HTTP route yet.

**Acceptance criteria:**
- [ ] A normalized name match and a point inside a circle both fit. Among the matches, a locality with a `locality_assignments` row wins over one with none. In that pool, the shortest haversine distance wins. Equal distance, or no point to measure, uses the earliest `created_at`. A fitting locality with no center is ordered after every fitting locality that has a numeric distance.
- [ ] No match creates a locality whose name is the trimmed, whitespace-collapsed place name, with a null center and a null radius.
- [ ] Ids are 36-character strings set on create. Claim does not update an existing locality's name, center, or radius.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/models/locality_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: none. The model test is the check.

**Dependencies:** None

**Files likely touched:**
- `backend/db/migrate/*_create_localities.rb`
- `backend/db/schema.rb`
- `backend/app/models/application_record.rb`
- `backend/app/models/locality.rb`
- `backend/app/models/locality_assignment.rb`
- `backend/test/models/locality_test.rb`

**Estimated scope:** Medium: 3–5 files, plus the generated schema

## Task 2: Enrolment records

**Description:** Persist one family unit, its members, and one enrolment per submission, and assign the locality from Task 1 at create time. The test calls a model method with already-clean attributes. Validation and HTTP wait for Task 3.

**Acceptance criteria:**
- [ ] One call creates one enrolment, one family unit, and members with the head first. A second call creates a second pair. `visit_at` is null. Optional blanks are empty strings, and blank age and amount are null.
- [ ] When `working` is false, `job` is empty and `monthly_amount` is null. Help keys are stored once in first-seen order.
- [ ] Changing the locality name, center, or radius afterward leaves `enrolment.locality_id` the same.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/models/enrolment_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: none. The model test is the check.

**Dependencies:** Task 1

**Files likely touched:**
- `backend/db/migrate/*_create_enrolments.rb`
- `backend/db/schema.rb`
- `backend/app/models/family_unit.rb`
- `backend/app/models/family_member.rb`
- `backend/app/models/enrolment.rb`
- `backend/test/models/enrolment_test.rb`

**Estimated scope:** Medium: 3–5 files, plus the generated schema

## Task 3: Accept an enrolment over HTTP

**Description:** `POST /enrolments` is anonymous and saves the whole form in one transaction. `EnrolmentSubmission` rejects bad input with the spec's `422` envelope and saves nothing. Coordinates on this task are stored as null; Task 4 adds the keep rule. The two consent sentences are chosen from `on_behalf` and a client-sent `consent_text` is ignored.

**Acceptance criteria:**
- [ ] A body with one named head and empty optional fields returns `201` with the spec's enrolment shape, `progress.case_in` true, `looks` empty, and `visit_at` null. No locality existed, so the new locality holds it. A second body creates a second enrolment and a second family unit. A matching place name uses the existing locality.
- [ ] Missing enroler phone, a non-phone contact, a missing place name, a missing head name, a gender outside the three values, a non-integer age, a non-integer monthly amount, a help key outside the four, zero members, two heads, or only one of latitude and longitude returns `422` with `VALIDATION_ERROR` and saves nothing.
- [ ] Self and on-behalf each store their own spec sentence. `latitude` and `longitude` in the `201` body are null.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/enrolments_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: `POST /enrolments` on port `3000` with one named head returns `201`. A body with no phone returns `422` and leaves the counts unchanged.

**Dependencies:** Task 2

**Files likely touched:**
- `backend/app/models/enrolment_submission.rb`
- `backend/app/controllers/enrolments_controller.rb`
- `backend/app/controllers/application_controller.rb`
- `backend/config/routes.rb`
- `backend/test/integration/enrolments_test.rb`

**Estimated scope:** Medium: 3–5 files

## Checkpoint: After Tasks 1–3

- [ ] `bin/ci` from the repository root exits 0
- [ ] A valid anonymous post creates one family and one enrolment
- [ ] An invalid post returns `422` and adds no row
- [ ] `GET /up` still returns success

## Task 4: Nearest locality with a center

**Description:** `GET /localities/suggestion` returns the nearest locality name, or `{ "locality": null }` when none have a center. `POST /enrolments` keeps a valid coordinate pair only when the place name matches that nearest locality. Any other name, including a name that creates a locality, stores null coordinates. Ties use the earliest `created_at`. There is no distance cutoff.

**Acceptance criteria:**
- [ ] The suggestion response is only `locality: null` or `locality.name`. It includes no workers, radii, or enrolments. A missing or out-of-range coordinate pair returns `422`.
- [ ] A kept point inside several circles assigns the closest staffed locality, or the closest locality when none are staffed. A fitting locality with no center loses to one with a numeric distance. Equal distance uses the earliest `created_at`.
- [ ] Coordinates whose place name matches the nearest locality with a center are stored. Any other name returns `latitude` and `longitude` as null and still saves the enrolment. A locality created by the enrolment has a null center and a null radius.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/localities_suggestion_test.rb test/integration/enrolments_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: `GET /localities/suggestion` with a point near a seeded center returns that locality's name only.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/app/models/locality.rb`
- `backend/app/models/enrolment_submission.rb`
- `backend/app/controllers/localities_controller.rb`
- `backend/config/routes.rb`
- `backend/test/integration/localities_suggestion_test.rb`
- `backend/test/integration/enrolments_test.rb`

**Estimated scope:** Medium: 3–5 files

## Task 5: Queue the invitation

**Description:** When the submission includes an email, enqueue one invitation after the enrolment commits. The mail has the spec's subject and body and no family name, place, phone, contact, or help. No email enqueues nothing. If enqueue raises, the enrolment remains and the response is still `201`. Looks and notes send no mail; this task covers the invitation side of that rule.

**Acceptance criteria:**
- [ ] An email enqueues one message with subject "Sokong enrolment" and body "An enrolment was received. Sign up with this email address to see whether anyone has looked and whether a visit is set."
- [ ] A blank email enqueues nothing. A raised enqueue error still leaves the enrolment saved and returns `201`.
- [ ] The test environment uses the Active Job test adapter, so the example asserts the message was enqueued.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/enrolments_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: submit with an email in development and confirm one message is in the job log, with none of the family fields in the body.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/app/mailers/enrolment_mailer.rb`
- `backend/app/views/enrolment_mailer/invitation.text.erb`
- `backend/app/controllers/enrolments_controller.rb`
- `backend/config/environments/test.rb`
- `backend/test/integration/enrolments_test.rb`

**Estimated scope:** Medium: 3–5 files

## Checkpoint: After Tasks 4–5

- [ ] `bin/ci` from the repository root exits 0
- [ ] A place name that matches the nearest center keeps the point
- [ ] Any other place name saves the enrolment with null coordinates
- [ ] One invitation is queued only when an email was submitted

## Task 6: Create a submitter account

**Description:** Uncomment `bcrypt` and add `POST /accounts`. The account is always a submitter. Password and confirmation must match, and the password is at least 12 characters. Email is unique case-insensitively.

**Acceptance criteria:**
- [ ] `201` returns `token` and `account` with `id`, `email`, and `role` `submitter`. A sent `role` field still persists `submitter`.
- [ ] A mismatch, a short password, a duplicate email under a different case, or a missing field returns `422` and creates no account.
- [ ] The response token is opaque. This task creates `auth_tokens` and stores a SHA-256 digest of the raw token. It also adds the foreign key from `locality_assignments.account_id` to accounts.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/accounts_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: `POST /accounts` with a 12-character password returns a submitter. The same call with `role` set to a worker still returns `submitter`.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/Gemfile`
- `backend/Gemfile.lock`
- `backend/db/migrate/*_create_accounts.rb`
- `backend/db/schema.rb`
- `backend/app/models/account.rb`
- `backend/app/models/auth_token.rb`
- `backend/app/controllers/accounts_controller.rb`
- `backend/config/routes.rb`
- `backend/test/integration/accounts_test.rb`

**Estimated scope:** Medium: one endpoint. The account, the token, the controller, the route, and the test are the behavior. The Gemfile, lockfile, migration, and schema come with them.

## Task 7: Sign in and sign out

**Description:** `POST /sessions` checks email and password and returns the same token payload as sign-up. A wrong pair returns `401` without saying whether the email exists. `DELETE /sessions` with a valid bearer token returns `204` and revokes it. Later tasks authenticate with `Authorization: Bearer`.

**Acceptance criteria:**
- [ ] A matching email, compared case-insensitively, and password return `200` with `token` and `account`. The stored credential is the digest of that new token.
- [ ] An unknown email and a wrong password both return `401` with code `UNAUTHENTICATED` and message "Email or password is wrong".
- [ ] `DELETE /sessions` returns `204` and a later request with that token returns `401` with message "Sign in is required". `spec.md` gains the `401` example.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/sessions_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: sign in, call a token-only route or `DELETE /sessions`, and confirm the revoked token receives `401`.

**Dependencies:** Task 6

**Files likely touched:**
- `backend/app/controllers/sessions_controller.rb`
- `backend/app/controllers/application_controller.rb`
- `backend/app/models/auth_token.rb`
- `backend/config/routes.rb`
- `backend/test/integration/sessions_test.rb`
- `context/requirements/features/enrolment/spec.md`

**Estimated scope:** Medium: 3–5 files

## Task 8: Submitter reads progress

**Description:** `GET /enrolments` and `GET /enrolments/:id` require a token. A submitter sees enrolments whose stored email matches the account email, case-insensitively, newest `submitted_at` first. Detail is the `201` shape plus `looks`. Anonymous callers receive `401`. An authenticated caller who must not see the record, including an unknown id, receives `404` with `NOT_FOUND` and no further detail.

**Acceptance criteria:**
- [ ] The matching submitter sees the case, an empty `looks` array, and `visit_at` null. Another submitter's enrolment is absent from the list and `404` on detail.
- [ ] A missing token returns `401`. A known token for a record that account must not see returns `404` with code `NOT_FOUND`, message "Not found", and no `details`.
- [ ] This read does not insert a look and does not enqueue mail. `spec.md` gains the `404` example.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/enrolments_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: sign up with the enrolment email and `GET /enrolments` returns that case only.

**Dependencies:** Task 7

**Files likely touched:**
- `backend/app/controllers/enrolments_controller.rb`
- `backend/app/controllers/application_controller.rb`
- `backend/test/integration/enrolments_test.rb`
- `context/requirements/features/enrolment/spec.md`

**Estimated scope:** Small: 1–2 files of behavior, plus the spec example

## Checkpoint: After Tasks 6–8

- [ ] `bin/ci` from the repository root exits 0
- [ ] An enrolment can still be submitted with no account
- [ ] The matching submitter can sign in and read that the case is in, with no looks and no visit
- [ ] A different account and an anonymous caller cannot read the record

## Task 9: Record a worker's first look

**Description:** A community worker linked to the enrolment's locality can list and open it. List items are the worker summary in the spec. Detail adds the family fields. The first detail read for that worker and enrolment inserts one look with the worker's name, the time, and an empty note, before the response is sent. A second open does not insert another. Opening the list does not insert one. A worker of another locality receives `404`.

**Acceptance criteria:**
- [ ] The linked worker's list returns `id`, `submitted_at`, `place_name`, `head_name`, `enroler_contact`, `on_behalf`, and `locality`, newest first, and inserts no look.
- [ ] The first detail read returns the family fields and one empty-note look. The second detail read returns that same look once. `visit_at` stays null. No mail is queued.
- [ ] A worker with no link to that locality, and a submitter requesting the worker-only fields by guessing, receives `404`. A worker with no links who lists enrolments receives `200` and an empty array.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/enrolments_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: create a worker and a link in the console, open the detail twice, and confirm one look row.

**Dependencies:** Task 8

**Files likely touched:**
- `backend/db/migrate/*_create_looks.rb`
- `backend/db/schema.rb`
- `backend/app/models/look.rb`
- `backend/app/models/account.rb`
- `backend/app/controllers/enrolments_controller.rb`
- `backend/test/integration/enrolments_test.rb`

**Estimated scope:** Medium: 3–5 files, plus the generated schema

## Task 10: Add a worker note

**Description:** `POST /enrolments/:id/looks` appends a look with the note for a worker linked to that locality. The note is non-blank text up to 2000 characters. A submitter receives `404`. The submitter's detail lists looks in time order. The post queues no mail.

**Acceptance criteria:**
- [ ] A linked worker receives `201` with the look: `id`, `worker_name`, `looked_at`, and `note`.
- [ ] A blank note or a note over 2000 characters returns `422` and adds no look. A submitter and a worker of another locality receive `404`.
- [ ] The matching submitter sees the empty-note look and the note in `looked_at` order. `visit_at` is still null. No mail is queued.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/enrolments_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: post a note as the worker, then read the enrolment as the submitter and see that note.

**Dependencies:** Task 9

**Files likely touched:**
- `backend/app/controllers/looks_controller.rb`
- `backend/app/models/look.rb`
- `backend/config/routes.rb`
- `backend/test/integration/enrolments_test.rb`

**Estimated scope:** Small: 1–2 files of behavior

## Task 11: Update a locality boundary

**Description:** `PATCH /localities/:id` lets a linked worker set the name, the center, and `radius_metres` from 1 through 200000. A radius without a center is `422`. Clearing the center and the radius together is allowed. A submitter or a worker of another locality receives `404`. Enrolments already saved keep their `locality_id`.

**Acceptance criteria:**
- [ ] `200` returns `id`, `name`, `latitude`, `longitude`, and `radius_metres` for a worker linked to that locality.
- [ ] A radius without a center, a radius outside 1 through 200000, or a name outside 1–200 characters returns `422`. Sending null latitude, longitude, and radius clears the circle.
- [ ] A submitter and a worker linked only to a different locality receive `404`. An enrolment saved before the patch still points at the same locality id.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/localities_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: patch a center and radius as the linked worker, then confirm an older enrolment still has the same `locality_id`.

**Dependencies:** Task 7

**Files likely touched:**
- `backend/app/controllers/localities_controller.rb`
- `backend/app/models/locality.rb`
- `backend/config/routes.rb`
- `backend/test/integration/localities_test.rb`

**Estimated scope:** Small: 1–2 files of behavior

## Task 12: Operator commands

**Description:** Add the three rake commands from the spec. They are not HTTP routes. `sokong:worker` creates a community worker. `sokong:locality` creates a locality and prints its id. `sokong:assign` links that account to that locality and succeeds again when the link is already there.

**Acceptance criteria:**
- [ ] `sokong:worker` with `EMAIL`, `NAME`, and a `PASSWORD` of at least 12 characters creates a community worker. A duplicate email or a short password fails and creates nothing.
- [ ] `sokong:locality` with `NAME` prints the new id. `sokong:assign` with that email and id creates the link, and a second run leaves a single link.
- [ ] An unknown email or an unknown locality id fails. No public route creates a worker or a link.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/tasks/sokong_rake_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: run the three commands from `backend` as written in `spec.md` and confirm the worker can sign in.

**Dependencies:** Task 6

**Files likely touched:**
- `backend/lib/tasks/sokong.rake`
- `backend/test/tasks/sokong_rake_test.rb`

**Estimated scope:** Small: 1–2 files

## Checkpoint: After Tasks 9–12

- [ ] `bin/ci` from the repository root exits 0
- [ ] The linked worker sees members, place, how to find them, phones, enroler contact, and help
- [ ] The first detail read stores one look, a note appears for the submitter, and `visit_at` stays empty
- [ ] Editing a locality name or circle does not move an enrolment already saved

## Task 13: Allow the web origin

**Description:** Enable the `rack-cors` gem already named in the Gemfile so the Nuxt dev server can call the API. The only allowed origin is `http://localhost:3001`.

**Acceptance criteria:**
- [ ] A request from `http://localhost:3001` receives `Access-Control-Allow-Origin` for that origin on the enrolment routes.
- [ ] A request from any other origin does not receive that allow-origin value.
- [ ] `GET /up` still returns success.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/cors_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: an OPTIONS preflight from `http://localhost:3001` is allowed.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/Gemfile`
- `backend/Gemfile.lock`
- `backend/config/initializers/cors.rb`
- `backend/test/integration/cors_test.rb`

**Estimated scope:** Small: 1–2 files of behavior, plus the lockfile

## Task 14: Scaffold the Nuxt app

**Description:** Create `web/` with the current Nuxt docs, `@nuxtjs/i18n`, and Vitest. English is the only locale, `defaultLocale` is `en`, and the routing strategy is `no_prefix`. Pages live at `web/pages/`. The dev server uses port `3001`. Root `bin/ci` runs the Rails gate and then `npm test` and `npm run lint`. The GitHub workflow runs those web checks on a pull request. One page renders a string from `en.json` so the shell is proven. Apply no product screen yet.

**Acceptance criteria:**
- [ ] `cd web && npm run dev -- --port 3001` serves the shell, and the visible sentence comes from `web/i18n/locales/en.json`.
- [ ] `npm test` and `npm run lint` pass. Root `bin/ci` runs them after the Rails gate. The GitHub workflow runs the same web checks.
- [ ] The dependency set is the scaffold, `@nuxtjs/i18n`, and the Vitest setup the tests need. Any other package is left out of this task.

**Verification:**
- [ ] Tests pass: `cd web && npm test && npm run lint`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: open `http://localhost:3001` and confirm the locale string renders. Confirm `web/pages/` is the pages directory. If Nuxt cannot use that path, update `spec.md` and stop.

**Dependencies:** Task 13

**Files likely touched:**
- `web/` (scaffold)
- `web/nuxt.config.ts`
- `web/i18n/locales/en.json`
- `web/pages/index.vue`
- `bin/ci`
- `.github/workflows/ci.yml`

**Estimated scope:** Medium: the generator owns the tree; hand edits stay in the files listed

## Checkpoint: After Tasks 13–14

- [ ] `bin/ci` from the repository root exits 0, including web test and lint
- [ ] The API allows `http://localhost:3001` and no other origin
- [ ] The web shell renders one English string from the locale file

## Task 15: Who is enrolling

**Description:** Stage 1 of the wizard. "This is my family" is selected on arrival. The consent sentence swaps with the mode. Next stays disabled until the phone matches the spec pattern. Email is optional. The step indicator shows the stage number and name. Typed values survive a later Back. Copy and tokens come from the spec and `design.md`.

**Acceptance criteria:**
- [ ] The two choices and the two consent sentences match `spec.md` word for word, read through `en.json`. A bad phone shows "Enter a phone number, for example +60 12-345 6789." and blocks Next.
- [ ] Back from a later stub stage returns with the phone, email, and mode intact.
- [ ] At 390 CSS pixels wide the stage scrolls vertically and does not scroll horizontally. Inputs are at least 44px tall.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: in the browser at 390 CSS pixels, switch to on behalf, enter a bad phone, then a valid phone, go forward and back, and confirm the values and the sentence.

**Dependencies:** Task 14

**Files likely touched:**
- `web/pages/index.vue`
- `web/components/EnrolmentWizard.vue`
- `web/components/StageEnroler.vue`
- `web/i18n/locales/en.json`
- `web/assets/sokong.css`
- `web/tests/enrolment-wizard.test.ts`

**Estimated scope:** Medium: 3–5 files

## Task 16: Record the family and the head

**Description:** Stage 2 collects the place, the optional family phone, and the head. Next requires a place name and a head name. Gender starts on Unspecified and offers only Male, Female, and Unspecified. Age is an integer or blank. Job and the monthly amount render only when working is on. On self-enrolment the family phone starts as the enroler's phone and keeps copying until the submitter edits or clears it. Switching to on behalf clears the family phone only while it is still that copy. On behalf, the family phone starts empty.

**Acceptance criteria:**
- [ ] Next is available only when the place name and the head name are non-blank. Back returns to stage 1 with both stages' values kept.
- [ ] Self-enrolment copies the enroler phone until the family phone is edited or cleared. A later change to the enroler phone updates the family phone only while the copy is still automatic. On behalf starts empty and clears an automatic copy when switching modes.
- [ ] Gender offers only those three labels. Age accepts an integer or blank. Job and amount are hidden when working is off. The component test covers this stage.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: at 390 CSS pixels, confirm the phone-copy rules, the working fields, and that Back keeps the head's name.

**Dependencies:** Task 15

**Files likely touched:**
- `web/components/StageFamily.vue`
- `web/components/MemberFields.vue`
- `web/components/EnrolmentWizard.vue`
- `web/i18n/locales/en.json`
- `web/tests/enrolment-wizard.test.ts`

**Estimated scope:** Medium: 3–5 files

## Task 17: Suggest the place from the device

**Description:** "Use my current location" asks the device for a point and calls `GET /localities/suggestion`. When a name comes back, it fills the place field and the screen says "This place was suggested from your current location." and "You can name a different place if you are not with the family." Editing the place name removes the suggested-from-location sentence. When the device returns a point and the suggestion is null, the screen says "Your current location was read. Name the place." Refusing the device, or never using the control, still allows Next once a place name is typed.

**Acceptance criteria:**
- [ ] A successful suggestion fills the place name and shows both sentences from the spec. Changing the name removes "This place was suggested from your current location."
- [ ] A point with no suggested locality shows "Your current location was read. Name the place." A refusal still allows Next after a typed place name.
- [ ] The point is sent on submit only when the place name is still the suggested name. The component test covers the three outcomes with a stubbed geolocation and a stubbed API.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: at 390 CSS pixels, with the API running and one locality center stored, use the control, then change the name and confirm the suggestion sentence disappears.

**Dependencies:** Tasks 4 and 16

**Files likely touched:**
- `web/components/StageFamily.vue`
- `web/composables/useApi.ts`
- `web/i18n/locales/en.json`
- `web/tests/enrolment-wizard.test.ts`

**Estimated scope:** Medium: 3–5 files

## Checkpoint: After Tasks 15–17

- [ ] `bin/ci` from the repository root exits 0
- [ ] Stages 1 and 2 keep typed values across Back
- [ ] The location control fills a suggested name and drops that sentence when the name changes
- [ ] Both stages fit a 390 CSS pixel width without horizontal scrolling

## Task 18: Other people in the family

**Description:** Stage 3 collects anyone besides the head. Zero other members is valid and Next is available immediately. Add a person inserts the same fields as the head, and that person needs a non-blank name before Next. Added people can be removed. The head is not on this stage.

**Acceptance criteria:**
- [ ] Next works with no added people. An added person with a blank name blocks Next. Remove drops that person and keeps the others.
- [ ] Each added person has the same fields and the same gender, age, and working rules as the head.
- [ ] Back returns to stage 2 with the added people intact. The component test covers zero people, one named person, and remove.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: at 390 CSS pixels, add a person, leave the name blank, fill it, go back, and confirm the person is still there.

**Dependencies:** Task 16

**Files likely touched:**
- `web/components/StageMembers.vue`
- `web/components/EnrolmentWizard.vue`
- `web/i18n/locales/en.json`
- `web/tests/enrolment-wizard.test.ts`

**Estimated scope:** Small: 1–2 files of behavior

## Task 19: Submit the enrolment and show confirmation

**Description:** Stage 4 collects how to find them, the four help choices, and a help that is not in the list. All may be empty. Description, how to find them, and the other-help field are textareas of at least three lines. Submit is available only on this stage and sends one `POST /enrolments`. The confirmation says the case is in and that no visit is set. When an email was entered, it also says to sign up with that email. There is no step indicator and no second submit on the confirmation.

**Acceptance criteria:**
- [ ] The help labels match the spec. An empty stage still submits. The textareas are at least three lines and keep their text on Back.
- [ ] A `201` replaces the wizard with "This case is in. No visit is set." The sign-up sentence appears only when an email was entered. A `422` shows the API message and stays on stage 4 with the typed values kept.
- [ ] The component test walks all four stages, including back, self phone-copy, on-behalf empty family phone, gender, integer age, and the textareas, then asserts the confirmation.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: at 390 CSS pixels, complete all four stages against the API, with and without an email, and confirm the two confirmation states. Confirm there is no horizontal scroll.

**Dependencies:** Tasks 3 and 18

**Files likely touched:**
- `web/components/StageNotes.vue`
- `web/components/EnrolmentConfirmation.vue`
- `web/components/EnrolmentWizard.vue`
- `web/composables/useApi.ts`
- `web/i18n/locales/en.json`
- `web/tests/enrolment-wizard.test.ts`

**Estimated scope:** Medium: 3–5 files

## Checkpoint: After Tasks 18–19

- [ ] `bin/ci` from the repository root exits 0
- [ ] The wizard submits one enrolment and shows that the case is in and that no visit is set
- [ ] An email shows the sign-up sentence. A blank email omits it
- [ ] Stages 3 and 4 and the confirmation fit a 390 CSS pixel width

## Task 20: Sign-up page

**Description:** `/sign-up` collects email, password, and confirmation, calls `POST /accounts`, and stores the returned token in `sessionStorage` under `sokong.token`. The page uses the `design.md` tokens. Copy lives in `en.json`.

**Acceptance criteria:**
- [ ] A matching password of at least 12 characters lands the submitter on `/enrolments` with the token stored.
- [ ] A `422` shows the API message and stores no token.
- [ ] At 390 CSS pixels the page scrolls vertically and does not scroll horizontally.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: sign up in the browser and confirm `sessionStorage` holds the token and the enrolments page opens.

**Dependencies:** Tasks 7 and 14

**Files likely touched:**
- `web/pages/sign-up.vue`
- `web/composables/useAuth.ts`
- `web/i18n/locales/en.json`
- `web/tests/auth.test.ts`

**Estimated scope:** Small: 1–2 files of behavior

## Task 21: Sign-in page

**Description:** `/sign-in` calls `POST /sessions` and stores the token the same way. A `401` shows "Email or password is wrong" and does not say whether the email exists. Sign-out clears the token and calls `DELETE /sessions`.

**Acceptance criteria:**
- [ ] A valid pair stores the token and opens `/enrolments`. A `401` shows "Email or password is wrong" and leaves storage empty.
- [ ] Sign-out removes `sokong.token` and a following API call has no bearer token.
- [ ] At 390 CSS pixels the page does not scroll horizontally.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: sign in, reload, confirm the token is still in `sessionStorage`, then sign out and confirm it is gone.

**Dependencies:** Task 20

**Files likely touched:**
- `web/pages/sign-in.vue`
- `web/composables/useAuth.ts`
- `web/i18n/locales/en.json`
- `web/tests/auth.test.ts`

**Estimated scope:** Small: 1–2 files of behavior

## Task 22: Submitter progress page

**Description:** `/enrolments` and `/enrolments/:id` for a submitter. With no looks, the detail says "This case is in. No one has looked. No visit is set." Looks render in time order with the worker's name, the time, and the note. A `401` sends the person to sign-in. A `404` says the case is not available.

**Acceptance criteria:**
- [ ] No looks shows that exact sentence. A note from the API shows under the worker's name in time order. `visit_at` null shows that no visit is set.
- [ ] Another account's id shows the not-available state. A missing token opens `/sign-in`.
- [ ] At 390 CSS pixels the list and the detail scroll vertically and do not scroll horizontally.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: submit an enrolment with an email, sign up, open the case, then as a worker add a note and confirm the submitter sees it after reload.

**Dependencies:** Tasks 8 and 21

**Files likely touched:**
- `web/pages/enrolments/index.vue`
- `web/pages/enrolments/[id].vue`
- `web/i18n/locales/en.json`
- `web/tests/progress.test.ts`

**Estimated scope:** Medium: 3–5 files

## Task 23: Worker cases page

**Description:** The same routes render the worker list and detail when the account is a community worker. No link shows "No locality is linked to this account." A link and no enrolments shows "No enrolments yet." Detail shows the members, place, how to find them, phones, enroler contact, and help. The first open is the detail GET, which records the look on the API. A note form posts the note. Opening the list records nothing.

**Acceptance criteria:**
- [ ] The two empty sentences match the spec. The detail shows the family fields the worker payload includes, and that no help was named when help is empty.
- [ ] Submitting a note shows it in the look list. A second visit to the detail does not duplicate the empty-note look.
- [ ] At 390 CSS pixels the worker case scrolls vertically and does not scroll horizontally.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: sign in as a linked worker, open a case twice, add a note, and confirm one empty look plus the note. Sign in as a worker with no link and confirm the empty sentence.

**Dependencies:** Tasks 10 and 21

**Files likely touched:**
- `web/pages/enrolments/index.vue`
- `web/pages/enrolments/[id].vue`
- `web/components/WorkerCase.vue`
- `web/i18n/locales/en.json`
- `web/tests/worker-case.test.ts`

**Estimated scope:** Medium: 3–5 files

## Task 24: Locality boundary page

**Description:** `/localities/:id` lets a linked worker set the name, the center, and the radius. The page uses the same tokens as the wizard. A `422` shows the API message. A `404` says the locality is not available. Saving does not claim to move existing enrolments.

**Acceptance criteria:**
- [ ] A valid name, center, and radius from 1 through 200000 saves and shows the returned values. Clearing the circle sends nulls and shows an empty circle.
- [ ] A radius without a center shows the `422` message and keeps the form values.
- [ ] At 390 CSS pixels the page does not scroll horizontally.

**Verification:**
- [ ] Tests pass: `cd web && npm test`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: as the linked worker, set a center and radius, reload, and confirm the values stuck. Open an enrolment saved earlier and confirm it still names the same locality.

**Dependencies:** Tasks 11 and 21

**Files likely touched:**
- `web/pages/localities/[id].vue`
- `web/i18n/locales/en.json`
- `web/tests/locality-boundary.test.ts`

**Estimated scope:** Small: 1–2 files of behavior

## Checkpoint: Complete

- [ ] `bin/ci` from the repository root exits 0
- [ ] Every acceptance line in Tasks 1–24 is checked
- [ ] At 390 CSS pixels, each wizard stage, the confirmation, submitter progress, and the worker case scroll vertically and do not scroll horizontally
- [ ] `GET /up` still returns success
- [ ] Ready for a review session. The next prompt is Review in `context/workflow/prompts.md`
