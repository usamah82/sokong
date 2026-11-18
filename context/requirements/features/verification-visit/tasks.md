# Tasks

Ordered by dependency. Each task is one session. Checkboxes live here. Decisions and the dependency graph are in [plan.md](plan.md). The contract is [spec.md](spec.md). The phone pictures are [design.md](design.md).

A `Checkpoint` is a review gate. Check it after the tasks above it. Do not open a pull request for a checkpoint.

A task is done only when its acceptance lines are true and [definition of done](../../../workflow/definition-of-done.md) is met. `bin/ci` from the repository root is the gate. It runs the Rails checks and the web test and lint scripts.

## Task 1: Set the visit over HTTP

**Description:** A worker linked to the enrolment's locality can store the pre-visit fields: `visit_at`, `bringing_basket`, and `assigned_workers`. `Enrolment#schedule_visit` accepts a zoned instant, including a past time and a time more than seven days after `submitted_at`. The checkbox is a JSON boolean. The names are one to ten strings, each 1–200 after trim. The same instant with the same checkbox and the same names returns success and does not write. The same instant with a different checkbox or name list stores those fields and queues no mail. A bad visit time, a non-boolean checkbox, or a bad name list is 422 and leaves the stored pre-visit fields as they were. `POST /enrolments` still returns `visit_at` null and does not return the new keys to the submitter.

**Acceptance criteria:**
- [x] `PATCH /enrolments/:id/visit` with a zoned instant, a boolean `bringing_basket`, and one to ten names returns 200 and those three fields. `visit_at` is that instant in UTC. A past time and a time more than `7 * 24` hours after `submitted_at` are stored. Members, place, and the consent sentence stay as submitted. The same instant, checkbox, and names return 200 and do not change `updated_at`.
- [x] A missing `visit_at`, a blank, a date with no time, a time with no zone, or an impossible date returns 422 "Visit time is invalid" and `details.visit_at` of `["is invalid"]`. A missing or non-boolean `bringing_basket` is "Bringing a basket is invalid". An empty name list, a blank name, a name past 200 characters, or more than ten names is "Assigned worker is required" or "Assigned worker is invalid". The stored pre-visit fields stay. Anonymous is 401. A submitter, a worker of another locality, an unlinked worker, and an unknown id are 404 "Not found".
- [x] Worker detail returns `visit_at`, `bringing_basket`, and `assigned_workers`. Worker list items and submitter `progress.visit_at` return the time only. The submitter body has no `bringing_basket` and no `assigned_workers`. A body larger than 128 KiB on this route returns 413 `PAYLOAD_TOO_LARGE` and stores nothing.

**Verification:**
- [x] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb test/integration/enrolments_test.rb`
- [x] Build succeeds: `bin/ci` from the repository root
- [x] Manual check: as a linked worker, `PATCH` a zoned time and see that time on `GET /enrolments/:id`. A date with no time returns 422 and leaves `visit_at` null.

**Dependencies:** None

**Files likely touched:**
- `backend/db/migrate/*_add_pre_visit_to_enrolments.rb`
- `backend/db/schema.rb`
- `backend/app/controllers/visits_controller.rb`
- `backend/app/models/enrolment.rb`
- `backend/app/models/verification_messages.rb`
- `backend/config/routes.rb`
- `backend/app/controllers/enrolments_controller.rb`
- `backend/test/integration/verifications_test.rb`
- `backend/test/integration/enrolments_test.rb`

**Estimated scope:** Medium. One migration, one route, the JSON helpers that already assert the whole body, and the new test file.

## Task 2: Queue the visit message

**Description:** The first stored visit time queues one message when the enrolment has an email. A later change of the instant queues a new message and leaves the earlier subject and body as first queued. The same instant queues nothing, including when only the checkbox or the assigned names change. A blank email queues nothing. A raised enqueue still leaves the visit saved and returns 200. The body names the enrolment head and `place_name`, and the month is English even when `I18n.locale` is not.

**Acceptance criteria:**
- [x] The subject is "Sokong visit". The first body is "A visit is set for {head} at {place}. The visit time is {utc}." A changed time uses "The visit time for {head} at {place} is now {utc}." `2026-11-24T01:00:00Z` is "24 November 2026 at 01:00 UTC" with `I18n.locale` set to a locale other than English.
- [x] The body contains no other member's name, either phone, the basket text, the bringing-a-basket answer, an assigned worker's name, an identity value, a document number, or an interview answer. The Active Job log for the enqueue contains neither the head, the place, nor the email.
- [x] A blank email queues nothing. The same instant queues nothing, including a PATCH that only changes `bringing_basket` or `assigned_workers`. A raised `deliver_later` returns 200, keeps the pre-visit fields, and logs the error class only. A look and a note still queue no mail.

**Verification:**
- [x] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb test/integration/looks_test.rb`
- [x] Build succeeds: `bin/ci` from the repository root
- [x] Manual check: set a visit on an enrolment that has an email and confirm one queued message. Change the time and confirm the first rendered body is unchanged.

**Dependencies:** Task 1

**Files likely touched:**
- `backend/app/mailers/enrolment_mailer.rb`
- `backend/app/controllers/visits_controller.rb`
- `backend/test/integration/verifications_test.rb`

**Estimated scope:** Medium: 3 files

## Checkpoint: After Tasks 1–2

- [x] `bin/ci` from the repository root exits 0
- [x] A linked worker can store a visit in the past and a visit later than a week, with the basket checkbox and an assigned name
- [x] One visit message is queued only when the email is present and the instant changes. A checkbox or name change on the same instant queues nothing. A changed time queues a second message
- [x] `GET /up` still returns success

## Task 3: Save Who is here

**Description:** Create the verification row and `PUT /enrolments/:id/verification/who_is_here`. The stage saves only after `visit_at` is stored. Every enrolment member must be in `people`. A visit-added person needs a name. Each person may carry a `documents` array, and zero documents is valid. A second PUT replaces Who is here and leaves the other columns null. Follow-ups the answer does not open are stored empty. The response is the saved stage plus `worker_name` and `recorded_at`.

**Acceptance criteria:**
- [x] A linked worker receives 200 when every enrolment member is present, including a person with no documents and a person with one document. `worker_name` is the account name at save time. `recorded_at` is the server time in UTC. Saving again replaces the column. The other columns stay null.
- [x] Omitting an enrolment member returns 422 "Person is required" and `details.family_member_id` of `["is required"]`, and the previous column stays. A missing visit returns 422 "Set the visit before recording it" and creates no verification row. A bad phone uses "Enter a phone number, for example +60 12-345 6789." A bad date, a bad identity, a bad document, a non-boolean, a duplicate person, an unknown `family_member_id`, or a string past its limit returns 422 and leaves the previous column unchanged.
- [x] A document kind is `national_id`, `social_security`, `passport`, `birth_certificate`, or `other`. A row needs a number of 1–100 characters. `other` needs "What document?" at 1–100, and any other kind stores that label empty. The messages are "Document is invalid", "Document number is required", and "What document? is required". An absent person keeps "Since when" and "Why". A person who is not absent stores those empty. A child stores "From where?" empty. A stage name outside the seven part keys, such as `wealth`, is 404. Anonymous is 401. An account that must not see the enrolment is 404.

**Verification:**
- [x] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb`
- [x] Build succeeds: `bin/ci` from the repository root
- [x] Manual check: set a visit, PUT a blank `who_is_here`, and PUT it again with one person. Confirm the second body is the one stored.

**Dependencies:** Task 1

**Files likely touched:**
- `backend/db/migrate/*_create_verifications.rb`
- `backend/db/schema.rb`
- `backend/app/models/verification.rb`
- `backend/app/models/who_is_here_stage.rb`
- `backend/app/models/verification_messages.rb`
- `backend/app/controllers/verifications_controller.rb`
- `backend/config/routes.rb`
- `backend/test/integration/verifications_test.rb`

**Estimated scope:** Medium. The migration and schema travel with the model.

## Task 4: Show the interview only to the linked worker

**Description:** Worker detail includes `verification`, null until the first saved part and then the six interview keys plus `boxes`. Submitter JSON has no verification key, no checkbox, and no assigned names. Worker list items do not include them. The request log filters the interview's names, phones, document numbers, assigned worker names, and free text.

**Acceptance criteria:**
- [x] After Who is here is saved, worker detail returns that stage and null for the other parts, including `boxes`. Before any save, `verification` is null. `marked_at` and `marker_name` are not added yet. Worker detail also returns `bringing_basket` and `assigned_workers`.
- [x] Submitter show and list bodies have no `verification`, `bringing_basket`, or `assigned_workers` key. A worker list item has `visit_at` and has no `verification` key. Another submitter and a worker of another locality still receive 404.
- [x] The parameter filter redacts `name`, `phone`, `number`, `other_label`, `assigned_workers`, `origin`, `notes`, `basket`, and the free-text answers. It leaves `gender`, `relationship`, `identity`, `kind`, and `stage` visible.

**Verification:**
- [x] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb test/integration/request_log_filter_test.rb`
- [x] Build succeeds: `bin/ci` from the repository root
- [x] Manual check: open the same enrolment as the linked worker and as the matching submitter. Only the worker body contains `verification`.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/app/controllers/enrolments_controller.rb`
- `backend/app/models/enrolment.rb`
- `backend/config/initializers/filter_parameter_logging.rb`
- `backend/test/integration/verifications_test.rb`
- `backend/test/integration/request_log_filter_test.rb`
- `backend/test/integration/enrolments_test.rb`

**Estimated scope:** Medium: 3–5 files, plus the existing JSON helper

## Task 5: Save how the family formed and how they are together

**Description:** `formation` and `dynamics` save on their own. A blank stage is valid. A year outside 1900 through the current UTC year is rejected with the spec sentence. The children answer is stored empty when Who is here has no child.

**Acceptance criteria:**
- [ ] Each stage returns 200 for blank answers and for filled answers. Replacing one leaves the other, and Who is here, unchanged.
- [ ] A string year, a year before 1900, and a year after the current UTC year return 422 "Enter the year, for example 2008." A year equal to the current UTC year returns 200.
- [ ] `children_at_home` is stored as `""` when no saved person has relationship `child`. It is kept when a child is saved. A string past 2000 characters returns 422 and leaves the previous column unchanged.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: PUT `formation` with a year, then PUT `dynamics`, and confirm Who is here is unchanged.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/app/models/formation_stage.rb`
- `backend/app/models/dynamics_stage.rb`
- `backend/app/models/verification.rb`
- `backend/test/integration/verifications_test.rb`

**Estimated scope:** Medium: 3–5 files

## Task 6: Save a day in their life

**Description:** `daily_life` stores one object per person the client sends. Working and school are independent. Follow-ups the answer does not open are stored empty. Skills stay either way. An empty people array is a saved blank stage.

**Acceptance criteria:**
- [ ] A person can be working and in school, either one, or neither. A Yes stores that side's answers. A No or a null stores that side empty and keeps `skills`.
- [ ] `monthly_amount` accepts a JSON integer from 0 through 999999999 and rejects a string, a float, and a number outside that range. `job` and `school_where` are limited to 200 characters. The long answers are limited to 2000.
- [ ] A failed PUT leaves the previous daily-life column unchanged and does not change the other stages.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: PUT one working person and one in-school person. Confirm the closed follow-ups are empty strings or null.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/app/models/daily_life_stage.rb`
- `backend/app/models/verification.rb`
- `backend/test/integration/verifications_test.rb`

**Estimated scope:** Medium: 3 files

## Checkpoint: After Tasks 3–6

- [ ] `bin/ci` from the repository root exits 0
- [ ] Who is here, formation, daily life, and dynamics each save and replace on their own
- [ ] The matching submitter's GET body has no `verification` key
- [ ] Interview names and free text are filtered from the request log

## Task 7: Save the house and the meals

**Description:** `house` stores the place, utilities, safety, meals, and the basket. Rent follow-ups are stored only when the place is rent. The unsafe follow-up is stored only when safe is false. A blank basket is valid on PUT.

**Acceptance criteria:**
- [ ] `place` accepts the four values and blank. Rent stores the amount and the behind flag. Any other place stores those empty. `safe: false` stores `unsafe_detail`. Any other safety value stores it empty.
- [ ] `sleeping_rooms` is null or an integer from 0 through 99. `rent_per_month` is null or an integer from 0 through 999999999. `meals` is blank or one of the four values. `basket` is blank or 1–500 characters.
- [ ] A bad place, a bad meals value, a non-integer, a non-boolean, or a basket past 500 characters returns 422 and leaves the previous house column unchanged.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: PUT a rented, unsafe house and confirm the follow-ups are stored. PUT `own` afterward and confirm the rent fields are empty.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/app/models/house_stage.rb`
- `backend/app/models/verification.rb`
- `backend/test/integration/verifications_test.rb`

**Estimated scope:** Medium: 3 files

## Task 8: Save what they need

**Description:** `needs` stores what the family needs most, the consent choice, and the closing note. Consent may be null on save. A non-boolean consent is rejected.

**Acceptance criteria:**
- [ ] A blank stage returns 200. `consent_given` true and false are stored. Null is stored.
- [ ] A string, a number, or an array for consent returns 422 "Consent is invalid" and leaves the previous needs column unchanged.
- [ ] `need_most` and `notes` over 2000 characters return 422 and leave the previous column unchanged. The other stages stay as they were.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: PUT consent false and confirm the stored value is the JSON boolean false.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/app/models/needs_stage.rb`
- `backend/app/models/verification.rb`
- `backend/test/integration/verifications_test.rb`

**Estimated scope:** Small: 3 files

## Task 9: Save the post-visit assessment

**Description:** `PUT /enrolments/:id/verification/boxes` stores Post-visit: Good family unit and Basic necessities, each as a boolean or null, plus both gap strings. A blank gap is valid on PUT whether the box is checked or not. `boxes` is not an interview stage. The mark rules wait for Task 10.

**Acceptance criteria:**
- [ ] A blank stage returns 200. Each box accepts true, false, and null. Both gaps and `notes` accept up to 2000 characters.
- [ ] A non-boolean box returns 422 "Good family unit is invalid" or "Basic necessities is invalid" and leaves the previous column unchanged.
- [ ] A gap past 2000 characters returns 422 and leaves the previous column unchanged. Dependable generation and accumulated wealth are not keys in the stored object.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: PUT both boxes false with one gap filled and one empty. Confirm both gap strings are stored.

**Dependencies:** Task 3

**Files likely touched:**
- `backend/app/models/boxes_stage.rb`
- `backend/app/models/verification.rb`
- `backend/test/integration/verifications_test.rb`

**Estimated scope:** Small: 3 files

## Checkpoint: After Tasks 7–9

- [ ] `bin/ci` from the repository root exits 0
- [ ] House, needs, and the post-visit assessment each save on their own
- [ ] A bad value on one stage leaves that stage's previous column in place
- [ ] A stage PUT before the visit is stored still returns 422 and saves nothing

## Task 10: Mark the family

**Description:** `POST /enrolments/:id/qualification` stores `qualified` or `disqualified` once the visit, every interview stage, and the post-visit assessment are saved and the mark-time fields are present. Identity is required only for people on the saved Who is here list. A missing document number does not reject the mark. Qualified also requires consent. The first mark returns 201. A second mark, a later visit, and a later stage return 422 and change nothing. No mail is queued in this task.

**Acceptance criteria:**
- [ ] The first qualified mark, with consent true and a complete interview and post-visit assessment, returns 201 with `outcome`, `marked_at`, and `marker_name`. `not_verified` and `no_papers` still allow qualified. A person with an empty `documents` array still allows either mark. Disqualified with consent false returns 201. The enrolment is still returned by GET for the worker and the matching submitter.
- [ ] A missing visit is "Set the visit before recording it". An unsaved interview stage or an unsaved `boxes` is "The visit record is incomplete", with `details` of that part's key and `["is required"]`. A blank basket, a null consent, a missing identity on a saved person, a missing relationship on a saved person other than the head, a null box, and a blank gap on an unchecked box use the field sentences in [plan.md](plan.md). Qualified with consent false is "The family has not consented". No outcome is stored.
- [ ] A second mark is "The mark is already set" and keeps `marked_at` and the first outcome, including when consent is false. After the mark, `PATCH` of the visit and `PUT` of a part return "Verification is finished" and change nothing. Worker detail includes `outcome`, `marked_at`, and `marker_name`. Submitter progress includes `outcome` and has no `marked_at`, `marker_name`, `verification`, `bringing_basket`, or `assigned_workers`. `POST /enrolments` returns `progress.outcome` null. This task queues no mail.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb test/integration/enrolments_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: complete a visit and mark it qualified. Mark it again and confirm 422 and the same `marked_at`. GET as the matching submitter shows `outcome` and no interview.

**Dependencies:** Tasks 3–9

**Files likely touched:**
- `backend/db/migrate/*_add_outcome_to_enrolments.rb`
- `backend/db/schema.rb`
- `backend/app/models/enrolment.rb`
- `backend/app/models/verification.rb`
- `backend/app/models/verification_messages.rb`
- `backend/app/controllers/qualifications_controller.rb`
- `backend/config/routes.rb`
- `backend/app/controllers/enrolments_controller.rb`
- `backend/test/integration/verifications_test.rb`
- `backend/test/integration/enrolments_test.rb`

**Estimated scope:** Medium. The migration, the mark rule, and the JSON keys land together so the existing exact-body tests stay true.

## Task 11: Queue the outcome message

**Description:** The first mark queues one message when the enrolment has an email. Qualified and disqualified use the same subject and the sentence for that outcome. A second mark queues nothing. A blank email still saves the mark. A raised enqueue still returns 201.

**Acceptance criteria:**
- [ ] The subject is "Sokong verification". Qualified body: "{head} at {place} is qualified." Disqualified body: "{head} at {place} is disqualified." The head is the enrolment head, and the place is `place_name`.
- [ ] The body contains no other member's name, either phone, the basket text, the bringing-a-basket answer, an assigned worker's name, an identity value, a document number, or an interview answer. The Active Job log omits the head, the place, and the email.
- [ ] A blank email queues nothing and still returns 201. A second mark queues nothing. A raised enqueue returns 201, keeps the outcome, and logs the error class only.

**Verification:**
- [ ] Tests pass: `cd backend && bin/rails test test/integration/verifications_test.rb`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: mark an enrolment that has an email and confirm one queued message. Mark again and confirm the delivery list does not grow.

**Dependencies:** Task 10

**Files likely touched:**
- `backend/app/mailers/enrolment_mailer.rb`
- `backend/app/controllers/qualifications_controller.rb`
- `backend/test/integration/verifications_test.rb`

**Estimated scope:** Small: 3 files

## Checkpoint: After Tasks 10–11

- [ ] `bin/ci` from the repository root exits 0
- [ ] A complete interview can be marked qualified or disqualified, and the family stays on record
- [ ] A second mark and a later edit return 422 and change nothing
- [ ] One outcome message is queued when the enrolment has an email

## Task 12: Pre-visit on the worker case

**Description:** The worker case shows Pre-visit: the aim sentence, the visit field, the "Bringing a basket" checkbox, and the assigned worker names. The name list starts with the signed-in worker. "Add a worker" adds a row, and a row that is present needs a name. After a time is stored the button reads Change visit, the UTC value sits on `<time datetime>`, and the visible text is the browser's local zone. A time more than seven days after `submitted_at` also shows the late sentence. Exactly seven days does not. Verification Interview, Post-visit, and both mark actions stay off the page until a visit is stored.

**Acceptance criteria:**
- [ ] The section heading is "Pre-visit". The page shows "Aim for a visit within a week of the enrolment.", "Set the visit before recording it.", a field labeled "Visit time", "Bringing a basket", and "Assigned workers". An empty or unparseable time shows "Visit time is invalid" and does not send. A present name row with a blank name does not send. A successful save shows the formatted time and "Change visit".
- [ ] `formatVisit` renders `2026-11-24T01:00:00Z` in `Asia/Kuala_Lumpur` as "24 November 2026 at 09:00". The late sentence appears only when the instant is later than `submitted_at` plus seven days. Changing only the checkbox or a name, with the same instant, does not expect a new visit message.
- [ ] The existing members, help, looks, and note form still render. At 390 CSS pixels the case does not scroll horizontally. Date, time, and number inputs use the same full-width rule as text inputs.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/worker-case.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: in the browser at 390 CSS pixels, set a visit with the checkbox and a worker name, see the local time, change it, and submit an empty field. Verification Interview and Post-visit are not on the page before the first successful save.

**Dependencies:** Task 2

**Files likely touched:**
- `web/utils/visitTime.ts`
- `web/components/VisitTime.vue`
- `web/components/WorkerCase.vue`
- `web/composables/useApi.ts`
- `web/i18n/locales/en.json`
- `web/assets/sokong.css`
- `web/test/nuxt/worker-case.spec.ts`

**Estimated scope:** Medium. The control, the client, the copy, and the case page are one screen.

## Task 13: Stage list and Who is here

**Description:** After a visit is stored, the case shows the six stage names under "Verification Interview". Who is here is the working stage. Back is absent there. Next and the stage list leave the stage and save it when it is valid. A bad phone stays on the stage with the typed values. Enrolment people stay on the list and have no Remove. Add a person and Remove apply to a person the visit found. Add a document adds a type and a number, and Other opens "What document?". The other stages open by name and do not send a PUT until their own task. Post-visit is not in this list.

**Acceptance criteria:**
- [ ] The heading is "Verification Interview". The six names stay visible while a stage is open. The open stage shows "Current". A saved stage shows "Saved". An unsaved stage shows "Not saved". An open saved stage shows both "Current" and "Saved".
- [ ] Enrolment name, gender, and the head's family phone sit above those fields, labeled "Enrolment". "From where?" is hidden for a child. Absent opens "Since when" and "Why". Yes on a guest or on care for elderly parents opens that follow-up. "The children are the people recorded here." is on the stage. A visit-added person with a blank name cannot leave the stage. "Add a document" adds Document and Number. Other shows "What document?". Zero documents can still leave the stage.
- [ ] `readonly` renders the stored answers as text and hides Add a person, Add a document, and Remove. At 390 CSS pixels the stage list and the open person do not scroll horizontally.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/worker-case.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: in the browser at 390 CSS pixels, jump away from Who is here with a bad phone and stay there. Fix it, press Next, and see Who is here marked Saved.

**Dependencies:** Tasks 4 and 12

**Files likely touched:**
- `web/components/interview/Interview.vue`
- `web/components/interview/WhoIsHere.vue`
- `web/components/WorkerCase.vue`
- `web/composables/useApi.ts`
- `web/i18n/locales/en.json`
- `web/test/nuxt/worker-case.spec.ts`

**Estimated scope:** Medium. One stage component plus the list that will hold the later stages.

## Task 14: Formation and how they are together

**Description:** How the family formed and How they are together become real stages. A bad year stays on formation. The children question is on dynamics only when Who is here has a child. Leaving either stage saves it. Back and Next move one stage.

**Acceptance criteria:**
- [ ] Formation shows "When did this family start?" and "How did it start?". A year outside 1900 through the current year shows "Enter the year, for example 2008." and does not open another stage.
- [ ] Dynamics shows the hard-week and who-steps-in questions, and "Write what the family said." "How are the children at home?" is shown only when a person is a Child. The screen says nothing that scores a person.
- [ ] Both stages save on leave, show Saved, and render as text when `readonly` is set. What they need still has no Next. Post-visit is not a stage in the list.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/worker-case.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: enter a bad year and confirm the stage does not change. Add a child on Who is here and confirm the children question appears on dynamics.

**Dependencies:** Tasks 5 and 13

**Files likely touched:**
- `web/components/interview/Formation.vue`
- `web/components/interview/Dynamics.vue`
- `web/components/interview/Interview.vue`
- `web/i18n/locales/en.json`
- `web/test/nuxt/worker-case.spec.ts`

**Estimated scope:** Medium: 3–5 files

## Task 15: A day in their life

**Description:** The stage asks the Who is here people, one at a time, head first. Working and school are independent. Enrolment working, education, job, and monthly amount sit above the matching fields. Switching person keeps what was typed and does not save. Leaving the stage saves every person.

**Acceptance criteria:**
- [ ] "Are you working?" and "Are you in school?" are always shown. Yes on working opens the job, the amount, previous jobs, and the wished work. "Any skills to highlight?" stays either way. Yes on school opens the three school questions.
- [ ] A No or an unselected choice hides its follow-up. The hidden answers are sent empty. Moving to the next person does not call PUT. Next from the stage does.
- [ ] `readonly` shows each person's stored answers as text. At 390 CSS pixels the open person does not scroll horizontally.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/worker-case.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: record one person as working and not in school, and another as in school and not working. Leave the stage and reload. Both answers are still there.

**Dependencies:** Tasks 6 and 13

**Files likely touched:**
- `web/components/interview/DailyLife.vue`
- `web/components/interview/Interview.vue`
- `web/i18n/locales/en.json`
- `web/test/nuxt/worker-case.spec.ts`

**Estimated scope:** Medium: 3–5 files

## Checkpoint: After Tasks 12–15

- [ ] `bin/ci` from the repository root exits 0
- [ ] The worker case can set a visit and save Who is here, formation, dynamics, and daily life
- [ ] A bad phone and a bad year stay on their stage
- [ ] At 390 CSS pixels those stages do not scroll horizontally

## Task 16: The house and the meals

**Description:** The house stage records the place, rent, utilities, safety, meals, and the basket. Rent opens the amount and the behind question. No on safety opens what feels unsafe. The basket is the last question before "Anything else they said".

**Acceptance criteria:**
- [ ] "This place" offers Own, Rent, Staying with someone, and Temporary. Rent shows "Rent per month" and "Are you behind on payments?". Water and electricity stay Yes and No. "How many meals a day?" offers the four spec labels.
- [ ] A place other than Rent hides the rent follow-ups and sends them empty. Yes or an unselected safety answer hides "What feels unsafe?" and sends it empty.
- [ ] Leaving the stage saves it. `readonly` renders the stored answers as text. The basket field is on this stage.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/worker-case.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: choose Rent and No for safety, confirm the follow-ups, then choose Own and confirm the rent fields are gone.

**Dependencies:** Tasks 7 and 13

**Files likely touched:**
- `web/components/interview/House.vue`
- `web/components/interview/Interview.vue`
- `web/i18n/locales/en.json`
- `web/test/nuxt/worker-case.spec.ts`

**Estimated scope:** Medium: 3–5 files

## Task 17: What they need

**Description:** The needs stage lists the enrolment help above the question, asks what the family needs most, and records one consent choice. Only the help keys stored on the enrolment are listed, with the spec's four labels.

**Acceptance criteria:**
- [ ] The stored help keys appear under "Enrolment" as Food, Clothing, School supplies, and Help applying to a body (for example social security, welfare, or a tithe body). A key that was not stored is absent. `other_help` stays in the existing help block and is not repeated here.
- [ ] "The family consents" and "The family does not consent" are one choice. Neither selected is sent as null.
- [ ] Leaving the stage saves it. This stage has Back and no Next. `readonly` renders the need and the consent as text.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/worker-case.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: open an enrolment whose help is food only. The needs stage lists Food and does not list Clothing.

**Dependencies:** Tasks 8 and 13

**Files likely touched:**
- `web/components/interview/Needs.vue`
- `web/components/interview/Interview.vue`
- `web/i18n/locales/en.json`
- `web/test/nuxt/worker-case.spec.ts`

**Estimated scope:** Small: 3–5 files

## Task 18: Post-visit and the mark

**Description:** Post-visit sits below the interview and is not a stage in the list. It records Initial assessment: the two boxes and their gaps, then offers Mark qualified and Mark disqualified. It shows "Saved" or "Not saved". An unchecked box with a blank gap shows "Gap is required" when a mark is pressed. Mark qualified also shows "The family has not consented" when the needs answer is false. The page still posts, and an API message that is already on screen is not repeated.

**Acceptance criteria:**
- [ ] The section heading is "Post-visit". "Initial assessment" names the judgment. It shows "Saved" or "Not saved", "This is your judgment from the visit.", and, under Good family unit, "Integrity, action, and selflessness, for the family as a whole." Dependable generation, accumulated wealth, and a status word are absent. The section is not in the stage list and has no Back and no Next.
- [ ] Both boxes and both Gap fields are visible. Pressing either mark with an unchecked box and a blank gap shows "Gap is required". Pressing Mark qualified when consent is false also shows "The family has not consented". An unsaved part shows the API message "The visit record is incomplete".
- [ ] A 201 stores the outcome on the case. The buttons read "Mark qualified" and "Mark disqualified". Saving the section calls `PUT /enrolments/:id/verification/boxes`.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/worker-case.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: at 390 CSS pixels, leave a gap blank and press both mark actions. Then fill the interview, mark the family, and see the 201 outcome on the case.

**Dependencies:** Tasks 9, 10, and 13

**Files likely touched:**
- `web/components/interview/Boxes.vue`
- `web/components/interview/Interview.vue`
- `web/composables/useApi.ts`
- `web/i18n/locales/en.json`
- `web/test/nuxt/worker-case.spec.ts`

**Estimated scope:** Medium: 3–5 files

## Checkpoint: After Tasks 16–18

- [ ] `bin/ci` from the repository root exits 0
- [ ] House, needs, and the two boxes save from the worker case
- [ ] Mark qualified and Mark disqualified post the outcome
- [ ] A blank gap and a refused consent are visible on Post-visit

## Task 19: Read-only after the mark

**Description:** Once an outcome is stored, the worker case hides Set visit, Change visit, Add a worker, Back, Next, Add a person, Add a document, and both mark actions. The stage list remains. Each stage and Post-visit open as text. Pre-visit is text. Qualified shows "This family is qualified." Disqualified shows "This family is disqualified."

**Acceptance criteria:**
- [ ] A qualified case shows "This family is qualified." A disqualified case shows "This family is disqualified." The visit time, the bringing-a-basket answer, and the assigned names stay visible as text, including the late sentence when it applies.
- [ ] The hidden actions are absent, not only disabled. Opening a stage or Post-visit shows the stored answers as text, including a document type and number. Enrolment facts remain visible above the answers they sit over.
- [ ] The note form still submits. At 390 CSS pixels the marked case does not scroll horizontally.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/worker-case.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: open a qualified case and a disqualified case at 390 CSS pixels. Confirm the actions are gone and each stage opens as text.

**Dependencies:** Tasks 12 and 18

**Files likely touched:**
- `web/components/interview/Interview.vue`
- `web/components/VisitTime.vue`
- `web/components/WorkerCase.vue`
- `web/i18n/locales/en.json`
- `web/test/nuxt/worker-case.spec.ts`

**Estimated scope:** Medium: 3–5 files

## Task 20: Submitter progress

**Description:** The matching submitter sees the visit time and the outcome, and does not see the interview. The quiet sentence stays for no looks and no visit. A stored visit replaces that sentence with "This case is in." and the local visit line. Looks with no visit still say "No visit is set."

**Acceptance criteria:**
- [ ] No looks and no visit render "This case is in. No one has looked. No visit is set." Looks and no visit render "This case is in." and "No visit is set."
- [ ] A stored visit renders "A visit is set for {local time}." in the same format as the worker case. Qualified adds "This family is qualified." Disqualified adds "This family is disqualified."
- [ ] The page does not render the interview, the bringing-a-basket answer, the assigned names, the basket text, consent, the identity check, a document number, the boxes, `marked_at`, or `marker_name`. At 390 CSS pixels it does not scroll horizontally.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/progress.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: sign in as the submitter and open the four states: quiet, a look and no visit, a visit, and qualified.

**Dependencies:** Tasks 2, 11, and 12

**Files likely touched:**
- `web/pages/enrolments/[id].vue`
- `web/i18n/locales/en.json`
- `web/test/nuxt/progress.spec.ts`

**Estimated scope:** Small: 3 files

## Task 21: Enrolments list

**Description:** Each row on the enrolments list shows the place, the head's name, the visit line, and the outcome line when an outcome is stored. A row with no outcome has no outcome line. The same lines are used for the submitter, who may have many enrolments, and for the worker.

**Acceptance criteria:**
- [ ] A submitter list of two enrolments shows each place, each head, and each visit line. One row with an outcome shows that outcome sentence. The other row has no outcome line.
- [ ] A worker list uses the same visit line and the same outcome line. "No visit is set." is the line when `visit_at` is null.
- [ ] At 390 CSS pixels the list does not scroll horizontally. Opening a row still goes to that case. Sign out still works.

**Verification:**
- [ ] Tests pass: `cd web && npx vitest run test/nuxt/progress.spec.ts test/nuxt/worker-case.spec.ts`
- [ ] Build succeeds: `bin/ci` from the repository root
- [ ] Manual check: at 390 CSS pixels, open the list as a submitter with two enrolments and as a worker. Each row shows its own visit and its own outcome.

**Dependencies:** Task 20

**Files likely touched:**
- `web/pages/enrolments/index.vue`
- `web/i18n/locales/en.json`
- `web/test/nuxt/progress.spec.ts`
- `web/test/nuxt/worker-case.spec.ts`

**Estimated scope:** Small: 3–5 files

## Checkpoint: After Tasks 19–21

- [ ] `bin/ci` from the repository root exits 0
- [ ] The marked worker case is text, and the visit and mark actions are gone
- [ ] Submitter progress shows the quiet sentence, the visit line, and the outcome
- [ ] The enrolments list shows each visit and each outcome for a submitter and for a worker
- [ ] A browser pass at 390 CSS pixels covers the worker case, submitter progress, and the enrolments list
- [ ] Ready for the run loop's walkthrough
