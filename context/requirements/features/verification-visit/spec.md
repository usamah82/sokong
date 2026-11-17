# Spec

Status: draft. The human moves the feature to `spec-approved`.

Catalog rows F06 and F07 are this feature. [intent.md](intent.md) stays the confirmed intent. This file says what "done" means.

This is one capability: the first verification visit and the mark that finishes it. The mark cannot be judged apart from the visit record, and the visit is not done until the family is qualified or disqualified.

## Objective

A community worker sets the first face-to-face visit for an enrolment, records what happened at that visit, and marks the family qualified or disqualified. That finishes Verification. Qualified means the family can move into Empowerment. This feature does not start the empowerment work.

The other user is the person who enrolled, including someone who enrolled many families. They see the visit time, and later they see qualified or disqualified. When the enrolment has an email, that address receives the visit message and the outcome message. Each message names the head and the place.

Sokong can store an enrolment today, and `visit_at` is always empty. No one can set a visit or mark a family.

The four records are the basket, the consent, the identity check, and the story. All four are stored before either mark. A visit later than a week after the enrolment is allowed. The screen says that a week is the aim. A disqualified family stays on record.

The story is two fields, because the intent left the fields to this spec and left the ongoing path to F09:

- `seen` is required. It is what the worker saw and heard that the enrolment form could not hold.
- `verified_correction` is optional. It is the facts the worker has seen and verified that differ from the enrolment. When it is not empty, the worker screen shows it as the account that outranks the enrolment. The enrolment rows are not rewritten.

The worker chooses the mark. The four Mara boxes are F08, so this feature does not derive qualified or disqualified from them. Qualified still requires the family's consent at the visit, because both enrolment sentences say that consent is confirmed then, and the on-behalf sentence says the family may not be enrolled without it. A refused consent can be marked disqualified once the four records are in. An identity that was not verified does not block either mark. A family can be on record with no papers.

## Tech Stack

- Rails 8.1 API in `backend/`, Ruby 3.4.11, SQLite for local and test databases. Module name `Backend`. URL paths stay unversioned (ADR-0003).
- The Nuxt app already in `web/` (ADR-0005). This feature adds to the worker case, the submitter progress page, and the enrolments list. It does not add a client.
- User-facing copy stays in `web/i18n/locales/en.json`. `defaultLocale` stays `en`. Routing strategy stays `no_prefix` (ADR-0006).
- Auth stays the opaque bearer token from the enrolment feature. These new routes require that token.
- Mail stays Action Mailer and Active Job. The test suite uses the test delivery adapter.
- CORS stays `http://localhost:3001` only.
- `GET /up` stays as it is.
- `visit_at` already exists on `enrolments` and is unused. This feature stores the visit time there. The outcome is new columns on `enrolments`. The four records are a new `verifications` row, one per enrolment.

## Commands

Repository gate, from the root:

```bash
bin/ci
```

API:

```bash
cd backend
bundle install
bin/rails db:prepare
bin/rails server
bin/rails test test/integration/verifications_test.rb
```

The server listens on port `3000`.

Web:

```bash
cd web
npm install
npm run dev -- --port 3001
npm test
npm run lint
```

No new operator command. Workers are still created with `sokong:worker` and linked with `sokong:assign`.

## Project Structure

Domain rules live on a model or one plain object under `backend/app/`, called by a thin controller. The rules are: the visit is set before the four records, the four records are in before a mark, qualified requires consent, and a finished verification does not change.

```
backend/app/models/verification.rb     one row per enrolment: the four records
backend/app/models/enrolment.rb        visit_at, outcome, marked_at, marker_name
backend/app/controllers/               visit, verification, and qualification
backend/app/mailers/enrolment_mailer.rb
backend/test/integration/verifications_test.rb
web/components/WorkerCase.vue          the visit section on the existing case
web/pages/enrolments/index.vue         visit and outcome on each row
web/pages/enrolments/[id].vue          submitter progress
web/i18n/locales/en.json               the copy in Success Criteria
web/test/nuxt/worker-case.spec.ts
web/test/nuxt/progress.spec.ts
```

The web app talks only to the HTTP contract in Success Criteria. Flutter is not created.

## Code Style

Rails follows `rubocop-rails-omakase` and `.cursor/rules/rails-api.mdc`. Web copy is read through the i18n module, including the aim sentence, the outcome sentences, and the errors.

The mark rule is not written in the controller:

```ruby
class Enrolment < ApplicationRecord
  def mark(outcome, worker:)
    return :visit_not_set if visit_at.nil?
    return :incomplete unless verification&.complete?
    return :consent_refused if outcome == "qualified" && !verification.consent_given?
    return :finished if self.outcome.present?

    update!(outcome:, marked_at: Time.current, marker_name: worker.name)
  end
end
```

`complete?` means basket, consent, identity method, identity verified, and `seen` are all present. `verified_correction` may be empty. The controller turns those symbols into the 422 messages in Success Criteria.

## Testing Strategy

`bin/ci` is the gate. Rails integration tests prove the HTTP contract, the order of the visit, the four records, the mark, who may see them, and the mail. Vitest proves the worker case and the submitter pages: the aim and late sentences, the four fields hidden until a visit is set, the read-only case after a mark, the quiet sentence only when nobody has looked and no visit is set, and a list of two enrolments showing each visit and each outcome. A browser pass at 390 CSS pixels wide checks the worker case, submitter progress, and the enrolments list. Those pages scroll vertically and do not scroll horizontally.

Edge cases the integration tests cover:

- A linked worker sets `visit_at` in the past, and sets one more than seven days after `submitted_at`. Both return 200. The stored column is that time. No locality, member, or consent sentence changes.
- A missing `visit_at`, a date with no time, or a value that is not a time returns 422 and leaves `visit_at` null. No mail is queued.
- Setting the same instant again returns 200 and queues no mail.
- The four records are rejected with "Set the visit before recording it" while `visit_at` is null, and nothing is saved.
- A complete record saves. A second PUT replaces that same row and does not insert another. Blank `verified_correction` is stored as empty.
- Basket, identity method, or `seen` blank or whitespace, a non-boolean consent or identity flag, or a string past its limit returns 422 and leaves the previous row unchanged.
- Qualified before the record exists, or with any of the four missing, returns 422, sets no outcome, and queues no mail.
- Consent refused, record complete: qualified returns 422 "The family has not consented" and sets no outcome. Disqualified returns 201 and the family is still returned by GET.
- Identity not verified, consent given, record complete: qualified returns 201.
- A second mark returns 422 "The mark is already set". `marked_at` and the first outcome stay. No second outcome mail is queued.
- After the mark, a new visit time or a replacement record returns 422 "Verification is finished" and changes nothing.
- An enrolment with an email queues one visit message on the first time, and a new message when the time changes. The first message's subject and body stay as first queued. The outcome message is queued once, on the mark.
- An enrolment with an empty email queues nothing for the visit or the mark. The rows are still saved. A mail exception still leaves the row saved and the HTTP status successful.
- The visit message and the outcome message contain the head name and the place name, and do not contain another member's name, either phone, the basket, the identity method, `seen`, or the correction.
- A look and a note still queue no mail. The first worker detail read still stores one look.
- The matching submitter sees `visit_at` and `outcome`, and the body has no verification object and none of the four fields. Another submitter, a worker of another locality, and an anonymous caller do not get the record.
- `POST /enrolments` still returns `visit_at` null and `outcome` null.
- A body larger than 128 KiB, or a chunked body, is 413 with `PAYLOAD_TOO_LARGE` and nothing is saved.
- `GET /up` still returns success.

## Boundaries

Left for later features:

- Needs, offers, and matching.
- Duplicate enrolments and reconciliation (F38).
- Changing a mark after it is set. The visit time and the four records are fixed at the same moment.
- The four Mara boxes, the status words, and deriving the mark from them (F08).
- The ongoing path: careers, school, births, assets, help already given, and decisions the family made (F09).
- The next visit, the three-month rhythm, and an unscheduled later visit (F12).
- Notifying the worker, or notifying a phone. Mail goes only to the enrolment email, and only for the visit time and the outcome.
- Accounts for benefactors, facilitators, and planners.
- Retention rules and a privacy request. Hosting is still undecided.
- The Flutter app, a production origin, and a production database.

Always:

- Run `bin/ci` before a code change is called done.
- Validate input at the controller. Keep the visit, record, and mark rules in the model or one plain object.
- Keep user-facing strings in `web/i18n/locales/en.json`.
- Keep basket, identity method, `seen`, `verified_correction`, enroler contact, family phone, email, and member name out of the request log.
- Return 404 when an account must not see a record, including when the id does not exist.
- Leave the saved visit or mark in place when the mail queue raises. Log the error class only.
- Leave `config/master.key` and `storage/` uncommitted.

Ask first:

- A new gem or npm dependency.
- Opening CORS to any origin other than `http://localhost:3001`.
- A second client.
- Changing `GET /up` or versioning a URL.

Never:

- Delete a disqualified enrolment, or hide it from the worker and the matching submitter.
- Change `outcome` after it is stored, or send a second outcome message.
- Rewrite enrolment members, place, phones, or the stored consent sentence from the verification record.
- Put another member, a phone, the basket, the identity check, or the story in either email, or in the submitter JSON.
- Reject a visit time because it is more than a week after `submitted_at`, or because identity was not verified.
- Require the four Mara boxes before a mark.
- Match a later enrolment against this one.
- Commit secrets, edit vendored skills, or drop a failing test to make the gate green.

## Success Criteria

### Visit

1. A worker linked to the enrolment's locality sets the first visit. A submitter, a worker of another locality, and an anonymous caller cannot. Anonymous is 401. An account that must not see the enrolment is 404 with `NOT_FOUND` and message "Not found".
2. `PATCH /enrolments/:id/visit` with `{ "visit_at": "2026-11-24T01:00:00Z" }` returns 200 and `{ "visit_at": "2026-11-24T01:00:00Z" }`. The value is ISO 8601 UTC and is stored on the existing `visit_at` column. A time in the past is valid. A time more than seven days after `submitted_at` is valid. Seven days is `7 * 24` hours, compared as instants.
3. Clearing `visit_at` is rejected. A missing key, a blank, a date with no time, or an unparseable value is 422 with message "Visit time is invalid" and `details.visit_at` of `["is invalid"]`. The stored time stays as it was.
4. The worker case shows "Aim for a visit within a week of the enrolment." When the stored `visit_at` is more than seven days after `submitted_at`, it also shows "This visit is later than a week after the enrolment." A time at exactly seven days does not show that second sentence. The `<time datetime>` is the UTC value from the API. The visible text is the browser's local zone, English, day without a leading zero, full month, year, and 24-hour time: a UTC+8 viewer of `2026-11-24T01:00:00Z` sees "24 November 2026 at 09:00".
5. Until a visit is stored, the four fields and both mark actions are not on the page. The page says "Set the visit before recording it." The button that stores a time reads "Set visit". When a time is already stored and the case is not marked, that button reads "Change visit".

### The four records

6. `PUT /enrolments/:id/verification` replaces the one verification row. It is rejected with message "Set the visit before recording it" and `details.visit_at` of `["is required"]` until `visit_at` is stored.
7. The body is the four records:

```json
{
  "basket": "A week's food and some cash",
  "consent_given": true,
  "identity_method": "No papers. The worker knows the mother from the block.",
  "identity_verified": false,
  "seen": "The youngest child has a learning disability. Rent and utilities are behind.",
  "verified_correction": "The middle child is out of school."
}
```

8. After trim, basket is 1–500 characters, identity method is 1–500, `seen` is 1–4000, and `verified_correction` is 0–2000. A missing correction or a blank correction is stored as empty. `consent_given` and `identity_verified` are JSON booleans. Any other type is invalid. A failed PUT does not change the stored row.
9. The 200 body is those fields plus `worker_name` and `recorded_at`. `worker_name` is the worker account's name at save time. `recorded_at` is the server time, ISO 8601 UTC. A later PUT overwrites this same row, including `worker_name` and `recorded_at`.
10. A blank or missing basket, identity method, or `seen` is "required". A blank or missing `verified_correction` is stored as empty and is not an error. A string past its limit is "too long". A value that is not a string, and a consent or identity flag that is not a JSON boolean, is "invalid". The messages are "Basket is required", "Basket is too long", "Basket is invalid", "Consent is invalid", "Identity is required", "Identity is too long", "Identity is invalid", "Identity check is invalid", "Story is required", "Story is too long", "Story is invalid", "Verified correction is too long", and "Verified correction is invalid". The `details` keys are `basket`, `consent_given`, `identity_method`, `identity_verified`, `seen`, and `verified_correction`, and each value is `["is required"]`, `["is too long"]`, or `["is invalid"]`. The envelope is the enrolment `VALIDATION_ERROR` shape. `message` is the first failing field in that key order. `details` lists every failing key.
11. On the worker case the labels are "Basket", "Consent", "The family consents", "The family does not consent", "Identity", "What was checked", "Identity was verified", "Identity was not verified", "Story", "What the form could not hold", and "Verified correction, optional". The save button reads "Save the visit record". When a correction is stored and not empty, the case shows it above the submitted family facts with the sentence "Verified. This outranks the enrolment." The submitted facts remain. When the correction is empty, that sentence is absent. The case also shows "Recorded by {worker_name}."

### Mark

12. `POST /enrolments/:id/qualification` with `{ "outcome": "qualified" }` or `{ "outcome": "disqualified" }` is the mark. Any other outcome, or a missing outcome, is 422 "Outcome is invalid" or "Outcome is required".
13. The mark is rejected with "Set the visit before recording it" when no visit is stored, and with "The visit record is incomplete" when any of basket, consent, identity method, identity verified, or `seen` is missing. `details` names each missing key as `["is required"]`. `verified_correction` is not required. No outcome is stored and no outcome mail is queued.
14. `qualified` is rejected with "The family has not consented" and `details.outcome` of `["needs consent"]` when `consent_given` is false. `disqualified` is allowed in that case. `identity_verified` false does not reject either outcome.
15. The first mark returns 201:

```json
{
  "outcome": "qualified",
  "marked_at": "2026-11-24T02:00:00Z",
  "marker_name": "Aman"
}
```

`marker_name` is the worker's name at that moment. `marked_at` is the server time. A second mark returns 422 "The mark is already set" and `details.outcome` of `["is already set"]`. The stored outcome and `marked_at` stay.
16. After the outcome is stored, `PATCH` of the visit and `PUT` of the verification return 422 "Verification is finished". The visit time, the four records, and the outcome stay as they were. No further visit or outcome mail is queued.
17. The marked worker case hides "Set visit", "Change visit", "Save the visit record", "Mark qualified", and "Mark disqualified". The stored time and the four records are text. Qualified shows "This family is qualified." Disqualified shows "This family is disqualified."
18. The family is not deleted. The worker and the matching submitter still receive the enrolment from GET. A later enrolment is not compared with this one.

### Who sees it

19. Worker detail adds `visit_at`, `verification` (null until the PUT), `outcome` (null until the mark), `marked_at`, and `marker_name`. Worker list items add `visit_at` and `outcome` only. They do not add the four records.
20. Submitter JSON keeps `progress.visit_at` and adds `progress.outcome`. Both are null on `POST /enrolments` and until the worker sets them. The submitter body does not include `verification`, basket, consent, identity, `seen`, `verified_correction`, `marked_at`, or `marker_name`.
21. The submitter progress page keeps "This case is in. No one has looked. No visit is set." for no looks and no visit. A stored visit uses the headline "This case is in." and the line "A visit is set for {local time}." in the same local format as the worker case. "No visit is set." remains the line when looks exist and no visit is stored. Qualified adds "This family is qualified." Disqualified adds "This family is disqualified."
22. Each row on the enrolments list shows the place, the head's name, the visit line ("A visit is set for {local time}." or "No visit is set."), and the outcome line when an outcome is stored. A row with no outcome has no outcome line. This holds for the submitter, who may have many enrolments, and for the worker.
23. At 390 CSS pixels wide, the worker case, submitter progress, and the enrolments list do not require horizontal scrolling.

### Mail

24. When `email` is empty, the visit and the mark queue nothing. When `email` is present, the first stored visit time queues one message. A later PATCH that changes the instant queues another message and does not alter the earlier message's subject or body. A PATCH that stores the same instant queues nothing.
25. The visit subject is "Sokong visit". The first body is "A visit is set for {head} at {place}. The visit time is {utc}." A changed time uses "The visit time for {head} at {place} is now {utc}." `{head}` is the member whose role is `head`. `{place}` is `place_name`. `{utc}` is the UTC time in the same English shape as the screen, with " UTC" after it. The month is the English name, including when the server locale is not English. `2026-11-24T01:00:00Z` is "24 November 2026 at 01:00 UTC".
26. The mark queues one message. The subject is "Sokong verification". Qualified body: "{head} at {place} is qualified." Disqualified body: "{head} at {place} is disqualified."
27. Neither message contains another member's name, the enroler phone, the family phone, the basket, the identity method, `seen`, or the correction. A look or a note queues no mail. If the queue raises, the visit or the mark stays saved and the response status stays 200 or 201.

### HTTP contract

JSON keys are snake_case. Times are ISO 8601 UTC. Ids are UUIDs. Paths are unversioned.

`PATCH /enrolments/:id/visit`, `PUT /enrolments/:id/verification`, and `POST /enrolments/:id/qualification` require a bearer token and the worker locality link used by `POST /enrolments/:id/looks`. A failed validation is 422:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The visit record is incomplete",
    "details": { "seen": ["is required"] }
  }
}
```

A body larger than 128 KiB, or a chunked body, stays 413 `PAYLOAD_TOO_LARGE`.

`GET /enrolments` and `GET /enrolments/:id` keep the enrolment shapes and add the fields in criteria 19 and 20. `visit_at` is no longer forced to null once a visit is stored.

## Open Questions

None.
