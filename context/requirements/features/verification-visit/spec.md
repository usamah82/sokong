# Spec

Status: draft. The human moves the feature to `spec-approved`.

Catalog rows F06 and F07 are this feature. The first two Mara boxes, and the gap for each, are recorded at the end of this visit. Dependable generation, accumulated wealth, earlier assessments, and the status word stay F08. [intent.md](intent.md) stays the confirmed intent. This file says what "done" means.

This is one capability: the first verification visit and the mark that finishes it. The mark cannot be judged apart from the visit record, and the visit is not done until the family is qualified or disqualified.

## Objective

A community worker sets the first face-to-face visit, then interviews the family and marks them qualified or disqualified. That finishes Verification. Qualified means the family can move into Empowerment. This feature does not start the empowerment work.

The other user is the person who enrolled, including someone who enrolled many families. They see the visit time, and later they see qualified or disqualified. When the enrolment has an email, that address receives the visit message and the outcome message. Each message names the head and the place.

Sokong can store an enrolment today, and `visit_at` is always empty. No one can set a visit or mark a family.

The interview is eight stages. The stage list stays on screen. The worker can open any stage, go back, and go forward. Each stage saves when they leave it. Empty answers are allowed. The enrolment is shown above a field it already answered, and the worker writes what the family said. That answer is the verified account. The enrolment rows stay as submitted.

The eight stages are Who is here, How the family formed, Who else stays, A day in their life, How they are together, The house and the meals, What they need, and The first two boxes. The basket is on the house stage. Consent is on the needs stage. The identity check is on the first stage. The story is the other answers. All of that is stored before either mark. A visit later than a week after the enrolment is allowed. The screen says that a week is the aim. A disqualified family stays on record.

On 2026-11-17 Usamah confirmed the closing judgment: this visit records Good family unit and Basic necessities, each with its gap. The other two boxes wait. The worker chooses the mark. Qualified still requires the family's consent at the visit. A refused consent can be marked disqualified once the interview is saved. Missing papers do not block either mark. A family can be on record with no papers.

Later additions to the path stay F09. This interview is the first story. It does not also collect a second list of careers, assets, and decisions.

## Tech Stack

- Rails 8.1 API in `backend/`, Ruby 3.4.11, SQLite for local and test databases. Module name `Backend`. URL paths stay unversioned (ADR-0003).
- The Nuxt app already in `web/` (ADR-0005). This feature adds the interview to the worker case, and adds the visit time and outcome to submitter progress and the enrolments list. It does not add a client.
- User-facing copy stays in `web/i18n/locales/en.json`. `defaultLocale` stays `en`. Routing strategy stays `no_prefix` (ADR-0006). The question labels below are that copy.
- Auth stays the opaque bearer token from the enrolment feature. These new routes require that token.
- Mail stays Action Mailer and Active Job. The test suite uses the test delivery adapter.
- CORS stays `http://localhost:3001` only.
- `GET /up` stays as it is.
- `visit_at` already exists on `enrolments` and is unused. This feature stores the visit time there. The outcome is new columns on `enrolments`. The interview is a new verification record, one per enrolment, saved one stage at a time.

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

Domain rules live on a model or one plain object under `backend/app/`, called by a thin controller. The rules are: the visit is set before a stage can be saved, every stage has been saved before a mark, qualified requires consent, an unchecked box has a gap, and a finished verification does not change.

```
backend/app/models/verification.rb     one interview per enrolment, saved by stage
backend/app/models/enrolment.rb        visit_at, outcome, marked_at, marker_name
backend/app/controllers/               visit, verification stage, and qualification
backend/app/mailers/enrolment_mailer.rb
backend/test/integration/verifications_test.rb
web/components/WorkerCase.vue          the visit time and the eight-stage interview
web/pages/enrolments/index.vue         visit and outcome on each row
web/pages/enrolments/[id].vue          submitter progress
web/i18n/locales/en.json               the copy in Success Criteria
web/test/nuxt/worker-case.spec.ts
web/test/nuxt/progress.spec.ts
```

The web app talks only to the HTTP contract in Success Criteria. Flutter is not created.

## Code Style

Rails follows `rubocop-rails-omakase` and `.cursor/rules/rails-api.mdc`. Web copy is read through the i18n module, including the stage names, the questions, the aim sentence, and the errors.

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

`complete?` means every stage has been saved, the basket is present, consent and the identity check are booleans, and both boxes are booleans with a gap when the box is unchecked. The controller turns those symbols into the 422 messages in Success Criteria.

## Testing Strategy

`bin/ci` is the gate. Rails integration tests prove the HTTP contract, the visit time, saving one stage, the mark, who may see the interview, and the mail. Vitest proves the worker case: the eight stage names stay visible, the open stage is marked current, a saved stage shows "Saved", jumping and Back and Next keep what was typed, a bad phone stays on that stage, the interview is hidden until a visit time is set, and the case is read-only after a mark. Vitest also proves the quiet sentence only when nobody has looked and no visit is set, and a list of two enrolments showing each visit and each outcome. A browser pass at 390 CSS pixels wide checks the worker case, submitter progress, and the enrolments list. Those pages scroll vertically and do not scroll horizontally.

Edge cases the integration tests cover:

- A linked worker sets `visit_at` in the past, and sets one more than seven days after `submitted_at`. Both return 200. The stored column is that time. No enrolment member, place, or consent sentence changes.
- A missing `visit_at`, a date with no time, or a value that is not a time returns 422 and leaves `visit_at` null. No mail is queued.
- Setting the same instant again returns 200 and queues no mail.
- A stage is rejected with "Set the visit before recording it" while `visit_at` is null, and nothing is saved.
- Saving one stage stores that stage and leaves the other stages as they were. Saving it again replaces that stage.
- A stage of blank answers returns 200 and is saved. A bad phone, a bad birth date, a non-boolean, a non-integer amount, or a string past its limit returns 422 and leaves the previous stage unchanged.
- Qualified before every stage is saved, or with the basket blank, consent missing, the identity check missing, or either box missing, returns 422, sets no outcome, and queues no mail.
- An unchecked box with a blank gap returns 422. A checked box with a blank gap is allowed.
- Consent refused, interview complete: qualified returns 422 "The family has not consented" and sets no outcome. Disqualified returns 201 and the family is still returned by GET.
- Identity not verified, consent given, interview complete: qualified returns 201.
- A second mark returns 422 "The mark is already set". `marked_at` and the first outcome stay. No second outcome mail is queued.
- After the mark, a new visit time or a replacement stage returns 422 "Verification is finished" and changes nothing.
- An enrolment with an email queues one visit message on the first time, and a new message when the time changes. The first message's subject and body stay as first queued. The outcome message is queued once, on the mark.
- An enrolment with an empty email queues nothing for the visit or the mark. The rows are still saved. A mail exception still leaves the row saved and the HTTP status successful.
- The visit message and the outcome message contain the head name and the place name, and do not contain another member's name, either phone, the basket, the identity check, or any interview answer.
- A look and a note still queue no mail. The first worker detail read still stores one look.
- The matching submitter sees `visit_at` and `outcome`, and the body has no verification object. Another submitter, a worker of another locality, and an anonymous caller do not get the record.
- `POST /enrolments` still returns `visit_at` null and `outcome` null.
- A body larger than 128 KiB, or a chunked body, is 413 with `PAYLOAD_TOO_LARGE` and nothing is saved.
- `GET /up` still returns success.

## Boundaries

Left for later features:

- Needs published to a benefactor, offers, and matching. The help the family asks for at this visit is stored here.
- Duplicate enrolments and reconciliation (F38).
- Changing a mark after it is set. The visit time and the interview are fixed at the same moment.
- Dependable generation, accumulated wealth, earlier assessments, the wealth exception, and the status word (the rest of F08).
- Later additions to the path (F09).
- The next visit, the three-month rhythm, and an unscheduled later visit (F12).
- Notifying the worker, or notifying a phone. Mail goes only to the enrolment email, and only for the visit time and the outcome.
- Accounts for benefactors, facilitators, and planners.
- Retention rules and a privacy request. Hosting is still undecided.
- The Flutter app, a production origin, and a production database.

Always:

- Run `bin/ci` before a code change is called done.
- Validate input at the controller. Keep the visit, stage, and mark rules in the model or one plain object.
- Keep user-facing strings in `web/i18n/locales/en.json`.
- Keep the interview answers, the basket, identification, enroler contact, family phone, email, and member name out of the request log.
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
- Rewrite enrolment members, place, phones, or the stored consent sentence from the interview.
- Put another member, a phone, the basket, the identity check, or an interview answer in either email, or in the submitter JSON.
- Reject a visit time because it is more than a week after `submitted_at`, or because identity was not verified.
- Require dependable generation or accumulated wealth before a mark.
- Score a person as Good, Self-sufficient, or Broken.
- Match a later enrolment against this one.
- Commit secrets, edit vendored skills, or drop a failing test to make the gate green.

## Success Criteria

### Visit

1. A worker linked to the enrolment's locality sets the first visit. A submitter, a worker of another locality, and an anonymous caller cannot. Anonymous is 401. An account that must not see the enrolment is 404 with `NOT_FOUND` and message "Not found".
2. `PATCH /enrolments/:id/visit` with `{ "visit_at": "2026-11-24T01:00:00Z" }` returns 200 and `{ "visit_at": "2026-11-24T01:00:00Z" }`. The value is ISO 8601 UTC and is stored on the existing `visit_at` column. A time in the past is valid. A time more than seven days after `submitted_at` is valid. Seven days is `7 * 24` hours, compared as instants.
3. Clearing `visit_at` is rejected. A missing key, a blank, a date with no time, or an unparseable value is 422 with message "Visit time is invalid" and `details.visit_at` of `["is invalid"]`. The stored time stays as it was.
4. The worker case shows "Aim for a visit within a week of the enrolment." When the stored `visit_at` is more than seven days after `submitted_at`, it also shows "This visit is later than a week after the enrolment." A time at exactly seven days does not show that second sentence. The `<time datetime>` is the UTC value from the API. The visible text is the browser's local zone, English, day without a leading zero, full month, year, and 24-hour time: a UTC+8 viewer of `2026-11-24T01:00:00Z` sees "24 November 2026 at 09:00".
5. Until a visit is stored, the interview and both mark actions are not on the page. The page says "Set the visit before recording it." The field is labeled "Visit time". The button that stores a time reads "Set visit". When a time is already stored and the case is not marked, that button reads "Change visit". The stored time keeps the label "Visit time".

### The interview

6. After a visit time is stored, the worker case shows a stage list that stays visible while a stage is open. The heading is "Interview". The stages, in order, are "Who is here", "How the family formed", "Who else stays", "A day in their life", "How they are together", "The house and the meals", "What they need", and "The first two boxes". The open stage shows "Current". A stage that has been saved shows "Saved". A stage that has not shows "Not saved". The worker opens any stage from that list. "Back" and "Next" move one stage. Stage 1 has no Back. Stage 8 has no Next.
7. Leaving a stage, by Back, Next, or the stage list, saves it when the answers are valid. Blank answers are valid. An invalid answer stays on that stage, shows the error, and does not open the other stage. Typed answers are still there.
8. `PUT /enrolments/:id/verification/:stage` saves that stage. `:stage` is `who_is_here`, `formation`, `who_else_stays`, `daily_life`, `dynamics`, `house`, `needs`, or `boxes`. Any other stage is 404. The call is rejected with "Set the visit before recording it" until `visit_at` is stored. A 200 body is the saved stage plus `worker_name` and `recorded_at`. `worker_name` is the worker account's name at save time. `recorded_at` is the server time, ISO 8601 UTC. A later PUT of the same stage replaces it and leaves the other stages unchanged.
9. Where the enrolment already holds a fact, the stage shows that fact above the field, labeled "Enrolment". The worker's answer is stored on the interview. The enrolment member, place, phone, and consent sentence stay as submitted. On the worker case, a stored interview answer is the account that outranks the enrolment, and the enrolment fact remains visible under it.
10. Each stage ends with "Anything else they said", optional text up to 2000 characters. The questions below are the field labels.

Who is here. The people already on the enrolment are listed, head first, then the other members. The worker opens one person at a time. For each person: "Full name", "Birth date", "Gender", "Phone", "Identification", and "Absent". An absent person also has "Since when" and "Why". "Add a person" adds someone the visit found, and that person needs a name before the stage can leave them on the list. An added person has "Remove". An enrolment person stays on the list and can be marked absent. The stage also asks "Identity was verified" and "Identity was not verified", one choice. The screen says "The children are the people recorded here."

How the family formed. "When did you two get together?", "How did you two get together?", "Where are you two from originally?", and "If either parent is absent, since when and why?"

Who else stays. "Who else stays with you, and why?" and "Do you have to take care of elderly parents?" The screen says "Children are recorded in Who is here."

A day in their life. The same people as Who is here, one person at a time, head first. "Are you working?", "Are you in school?", "What job?", "How much do you earn?", "Any previous jobs?", "Any skills to highlight?", "If you wish for a new job or income, what would that be?", "How are you doing in school?", "Where is your school?", and "How do you get to school?" Working and school are independent. Both may be true. Both may be false.

How they are together. "How do you feel about your life?", "If there is one thing you need to better your life, what is that?", "Do you feel depressed?", "Is your spouse not present?", and "Are the kids rebellious?" The screen says "Write what the family said."

The house and the meals. "Is this place permanent?", "Are you renting?", "How much is the rent?", "Are you behind on payments?", "Does it have water?", "Does it have electricity?", "Is it too crowded?", "Is this place safe?", "Any threats?", "Do you get 3 meals a day?", and "Basket".

What they need. "What do you need most?", then "The family consents" and "The family does not consent", one choice.

The first two boxes. "Good family unit" and "Basic necessities", each checked or not, and under each a "Gap". The screen says "This is your judgment from the visit." Dependable generation and accumulated wealth are not on the screen. The mark actions are on this stage.
11. Limits, after trim. Full name is 1–200 when that person is kept. Phone uses the enrolment phone rule and is optional. A value that fails that rule stays on the stage and shows "Enter a phone number, for example +60 12-345 6789." Birth date is `YYYY-MM-DD` or empty. Gender is `male`, `female`, or `unspecified`, shown as Male, Female, and Unspecified. Identification, job, school, and threats are 0–500. The questions, the gap, and "Anything else they said" are 0–2000. "How much do you earn?" and "How much is the rent?" are empty or a JSON integer from 0 through 999999999. Yes/no answers are labeled "Yes" and "No". They and the two boxes are JSON booleans or empty while the worker is still on the stage. A failed PUT does not change the stored stage.
12. Basket, when present, is 1–500 characters. Consent and the identity check, when present, are booleans. A blank or missing required value at mark time uses the enrolment `VALIDATION_ERROR` shape. The messages are "Basket is required", "Basket is too long", "Consent is invalid", "Identity check is invalid", "Good family unit is required", "Basic necessities is required", and "Gap is required". `details` names `basket`, `consent_given`, `identity_verified`, `good_family_unit`, `basic_necessities`, and `gap`. A string past its limit is "too long", a bad type is "invalid", and a missing mark-time value is "required". `message` is the first failing field.

### Mark

13. `POST /enrolments/:id/qualification` with `{ "outcome": "qualified" }` or `{ "outcome": "disqualified" }` is the mark. The buttons read "Mark qualified" and "Mark disqualified" and are on "The first two boxes". Any other outcome, or a missing outcome, is 422 "Outcome is invalid" or "Outcome is required".
14. The mark is rejected with "Set the visit before recording it" when no visit is stored, and with "The visit record is incomplete" when any stage has not been saved, the basket is blank, consent is missing, the identity check is missing, or either box is missing. An unchecked box with a blank gap is "Gap is required". No outcome is stored and no outcome mail is queued.
15. `qualified` is rejected with "The family has not consented" and `details.outcome` of `["needs consent"]` when consent is false. `disqualified` is allowed in that case. `identity_verified` false does not reject either outcome. Either box may be checked or unchecked for either outcome.
16. The first mark returns 201:

```json
{
  "outcome": "qualified",
  "marked_at": "2026-11-24T02:00:00Z",
  "marker_name": "Aman"
}
```

`marker_name` is the worker's name at that moment. `marked_at` is the server time. A second mark returns 422 "The mark is already set" and `details.outcome` of `["is already set"]`. The stored outcome and `marked_at` stay.
17. After the outcome is stored, `PATCH` of the visit and `PUT` of a stage return 422 "Verification is finished". The visit time, the interview, and the outcome stay as they were. No further visit or outcome mail is queued.
18. The marked worker case hides "Set visit", "Change visit", "Back", "Next", "Add a person", and both mark actions. The stage list remains. Each stage opens as text. Qualified shows "This family is qualified." Disqualified shows "This family is disqualified."
19. The family is not deleted. The worker and the matching submitter still receive the enrolment from GET. A later enrolment is not compared with this one. The screen does not show a status word.

### Who sees it

20. Worker detail adds `visit_at`, `verification` (null until the first stage is saved, then the eight stages), `outcome` (null until the mark), `marked_at`, and `marker_name`. Worker list items add `visit_at` and `outcome` only. They do not add the interview.
21. Submitter JSON keeps `progress.visit_at` and adds `progress.outcome`. Both are null on `POST /enrolments` and until the worker sets them. The submitter body does not include `verification`, the basket, consent, the identity check, the interview, the two boxes, `marked_at`, or `marker_name`.
22. The submitter progress page keeps "This case is in. No one has looked. No visit is set." for no looks and no visit. A stored visit uses the headline "This case is in." and the line "A visit is set for {local time}." in the same local format as the worker case. "No visit is set." remains the line when looks exist and no visit is stored. Qualified adds "This family is qualified." Disqualified adds "This family is disqualified."
23. Each row on the enrolments list shows the place, the head's name, the visit line ("A visit is set for {local time}." or "No visit is set."), and the outcome line when an outcome is stored. A row with no outcome has no outcome line. This holds for the submitter, who may have many enrolments, and for the worker.
24. At 390 CSS pixels wide, the worker case, including the stage list and an open stage, submitter progress, and the enrolments list do not require horizontal scrolling.

### Mail

25. When `email` is empty, the visit and the mark queue nothing. When `email` is present, the first stored visit time queues one message. A later PATCH that changes the instant queues another message and does not alter the earlier message's subject or body. A PATCH that stores the same instant queues nothing.
26. The visit subject is "Sokong visit". The first body is "A visit is set for {head} at {place}. The visit time is {utc}." A changed time uses "The visit time for {head} at {place} is now {utc}." `{head}` is the member whose role is `head` on the enrolment. `{place}` is `place_name`. `{utc}` is the UTC time in the same English shape as the screen, with " UTC" after it. The month is the English name, including when the server locale is not English. `2026-11-24T01:00:00Z` is "24 November 2026 at 01:00 UTC".
27. The mark queues one message. The subject is "Sokong verification". Qualified body: "{head} at {place} is qualified." Disqualified body: "{head} at {place} is disqualified."
28. Neither message contains another member's name, the enroler phone, the family phone, the basket, the identity check, or an interview answer. A look or a note queues no mail. If the queue raises, the visit or the mark stays saved and the response status stays 200 or 201.

### HTTP contract

JSON keys are snake_case. Times are ISO 8601 UTC. Ids are UUIDs. Paths are unversioned.

`PATCH /enrolments/:id/visit`, `PUT /enrolments/:id/verification/:stage`, and `POST /enrolments/:id/qualification` require a bearer token and the worker locality link used by `POST /enrolments/:id/looks`. A failed validation is 422:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The visit record is incomplete",
    "details": { "basket": ["is required"] }
  }
}
```

A body larger than 128 KiB, or a chunked body, stays 413 `PAYLOAD_TOO_LARGE`.

`GET /enrolments` and `GET /enrolments/:id` keep the enrolment shapes and add the fields in criteria 20 and 21. `visit_at` is no longer forced to null once a visit is stored.

## Open Questions

None.
