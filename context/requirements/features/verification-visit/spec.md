# Spec

Status: revised 2026-11-18, waiting for approval with the plan.

Usamah approved the previous text on 2026-11-17, after accepting the screenshots. On 2026-11-18, during plan review, he asked for a pre-visit section, document numbers on each person, and the initial assessment moved into a post-visit section. This file is that revision.

Catalog rows F06 and F07 are this feature. The first two Mara boxes, and the gap for each, are recorded at the end of this visit. Dependable generation, accumulated wealth, earlier assessments, and the status word stay F08. [intent.md](intent.md) stays the confirmed intent. This file says what "done" means.

This is one capability: the first verification visit and the mark that finishes it. The mark cannot be judged apart from the visit record, and the visit is not done until the family is qualified or disqualified.

## Objective

A community worker sets the first face-to-face visit, then interviews the family and marks them qualified or disqualified. That finishes Verification. Qualified means the family can move into Empowerment. This feature does not start the empowerment work.

The other user is the person who enrolled, including someone who enrolled many families. They see the visit time, and later they see qualified or disqualified. When the enrolment has an email, that address receives the visit message and the outcome message. Each message names the head and the place.

Sokong can store an enrolment today, and `visit_at` is always empty. No one can set a visit or mark a family.

The worker case has three sections. Pre-visit is where the worker sets the visit time, records whether they are bringing a basket, and names the community workers assigned to the visit. Verification Interview is six stages. Post-visit is the initial assessment: Good family unit and Basic necessities, each with its gap, and the mark. The stage list stays on screen during the interview. The worker can open any interview stage, go back, and go forward. Each stage saves when they leave it. Empty answers are allowed. A follow-up stays off the screen until the answer that opens it. The enrolment is shown above a field it already answered, and the worker writes what the family said. That answer is the verified account. The enrolment rows stay as submitted.

The six stages are Who is here, How the family formed, A day in their life, How they are together, The house and the meals, and What they need. Who is here includes the people who stay. The basket that was taken is on the house stage. The pre-visit checkbox only records whether the workers are bringing one. Consent is on the needs stage. The identity check is on the first stage, once for each person. Document numbers are recorded there too, and they are optional. The story is the other answers. All of that, and the post-visit assessment, is stored before either mark. A visit later than a week after the enrolment is allowed. The screen says that a week is the aim. A disqualified family stays on record.

The identity check is the worker's choice for each person on Who is here: Verified, Not verified, or No papers. It says whether the worker could confirm who the person is. The document numbers are a separate record, kept so a qualified family can be helped to apply for government help later. This feature stores the numbers and does not submit them anywhere. The people already on the enrolment stay on the Who is here list, and the worker cannot remove them. The worker can add a person the visit found and can remove only that added person. Before either mark, every person on the saved list has one of the three identity choices. Not verified and No papers still allow either mark. A missing document number does not block either mark.

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
- `visit_at` already exists on `enrolments` and is unused. This feature stores the visit time there, and adds `bringing_basket` and `assigned_workers` on the same row for the pre-visit section. The outcome is new columns on `enrolments`. The interview and the post-visit assessment are one verification record per enrolment. The six interview stages and the post-visit assessment are JSON columns on that row, and each one is saved on its own. A null column means that part has not been saved.

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
backend/app/models/verification.rb     six interview stages and the post-visit assessment
backend/app/models/enrolment.rb        visit_at, bringing_basket, assigned_workers, outcome, marked_at, marker_name
backend/app/controllers/               visit, verification stage, and qualification
backend/app/mailers/enrolment_mailer.rb
backend/test/integration/verifications_test.rb
web/components/WorkerCase.vue          pre-visit, the six-stage interview, and post-visit
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

`complete?` means every interview stage and the post-visit assessment have been saved, the basket text is present, consent is a boolean, every person on the saved Who is here list has an identity choice, every person on that list who is not the head has a relationship, and both boxes are booleans with a gap when the box is unchecked. The controller turns those symbols into the 422 messages in Success Criteria.

## Testing Strategy

`bin/ci` is the gate. Rails integration tests prove the HTTP contract, the pre-visit fields, saving one stage, the mark, who may see the interview, and the mail. Vitest proves the worker case: the six stage names stay visible under "Verification Interview", the open stage is marked current, a saved stage shows "Saved", Post-visit shows "Saved" or "Not saved", jumping and Back and Next keep what was typed, a bad phone stays on that stage, a No or an unselected choice hides its follow-up, the interview and Post-visit are hidden until a visit time is set, and the case is read-only after a mark. Vitest also proves the quiet sentence only when nobody has looked and no visit is set, and a list of two enrolments showing each visit and each outcome. A browser pass at 390 CSS pixels wide checks the worker case, submitter progress, and the enrolments list. Those pages scroll vertically and do not scroll horizontally.

Edge cases the integration tests cover:

- A linked worker sets `visit_at` in the past, and sets one more than seven days after `submitted_at`. Both return 200 with `bringing_basket` and at least one assigned name. The stored column is that time. No enrolment member, place, or consent sentence changes. The same instant with a different checkbox or a different name list returns 200, stores those fields, and queues no mail.
- A missing `visit_at`, a date with no time, or a value that is not a time returns 422 and leaves `visit_at` null. A missing `bringing_basket`, a missing assigned name, or an empty assigned list returns 422 and leaves the stored pre-visit fields as they were. No mail is queued.
- Setting the same instant again returns 200 and queues no mail.
- A stage is rejected with "Set the visit before recording it" while `visit_at` is null, and nothing is saved.
- Saving one stage stores that stage and leaves the other stages as they were. Saving it again replaces that stage.
- A stage of blank answers returns 200 and is saved. A follow-up that the answer does not open is stored empty. A bad phone, a bad birth date, a bad year, a bad relationship, a bad identity choice, a bad document, a bad place choice, a bad meals choice, a non-boolean, a non-integer amount, or a string past its limit returns 422 and leaves the previous stage unchanged. Who is here without one of the enrolment's people returns 422 and leaves the previous stage unchanged.
- Qualified before every interview stage is saved, before the post-visit assessment is saved, or with the basket text blank, consent missing, a person on the saved Who is here list missing an identity choice, a person on that list other than the head missing a relationship, or either box missing, returns 422, sets no outcome, and queues no mail. A person with no document number does not cause that rejection.
- An unchecked box with a blank gap returns 422. A checked box with a blank gap is allowed.
- Consent refused, interview complete: qualified returns 422 "The family has not consented" and sets no outcome. Disqualified returns 201 and the family is still returned by GET.
- A person on the saved list whose identity is `not_verified` or `no_papers`, consent given, interview and post-visit complete: qualified returns 201.
- A second mark returns 422 "The mark is already set". `marked_at` and the first outcome stay. No second outcome mail is queued.
- After the mark, a new visit time or a replacement stage returns 422 "Verification is finished" and changes nothing.
- An enrolment with an email queues one visit message on the first time, and a new message when the time changes. The first message's subject and body stay as first queued. The outcome message is queued once, on the mark.
- An enrolment with an empty email queues nothing for the visit or the mark. The rows are still saved. A mail exception still leaves the row saved and the HTTP status successful.
- The visit message and the outcome message contain the head name and the place name, and do not contain another member's name, either phone, the basket, the bringing-a-basket answer, an assigned worker's name, the identity check, a document number, or any interview answer.
- A look and a note still queue no mail. The first worker detail read still stores one look.
- The matching submitter sees `visit_at` and `outcome`, and the body has no verification object. Another submitter, a worker of another locality, and an anonymous caller do not get the record.
- `POST /enrolments` still returns `visit_at` null and `outcome` null.
- A body larger than 128 KiB, or a chunked body, is 413 with `PAYLOAD_TOO_LARGE` and nothing is saved.
- `GET /up` still returns success.

## Boundaries

Left for later features:

- Needs published to a benefactor, offers, and matching. The help the family asks for at this visit is stored here. Applying to a government body with the stored document numbers is a later feature.
- Duplicate enrolments and reconciliation (F38).
- Changing a mark after it is set. The visit time, the pre-visit fields, the interview, and the post-visit assessment are fixed at the same moment.
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
- Keep the interview answers, the basket, document numbers, enroler contact, family phone, email, assigned worker names, and member name out of the request log.
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
- Put another member, a phone, the basket, the bringing-a-basket answer, an assigned worker's name, the identity check, a document number, or an interview answer in either email, or in the submitter JSON.
- Reject a visit time because it is more than a week after `submitted_at`, or because identity was not verified, or because a person has no papers.
- Require dependable generation or accumulated wealth before a mark.
- Score a person as Good, Self-sufficient, or Broken.
- Match a later enrolment against this one.
- Commit secrets, edit vendored skills, or drop a failing test to make the gate green.

## Success Criteria

### Pre-visit

1. A worker linked to the enrolment's locality sets the first visit. A submitter, a worker of another locality, and an anonymous caller cannot. Anonymous is 401. An account that must not see the enrolment is 404 with `NOT_FOUND` and message "Not found".
2. `PATCH /enrolments/:id/visit` with `{ "visit_at": "2026-11-24T01:00:00Z", "bringing_basket": true, "assigned_workers": ["Aman"] }` returns 200 and those three fields. `visit_at` is ISO 8601 UTC and is stored on the existing column. A time in the past is valid. A time more than seven days after `submitted_at` is valid. Seven days is `7 * 24` hours, compared as instants. `bringing_basket` is a JSON boolean. `assigned_workers` is an array of one to ten names, each 1–200 characters after trim. The screen starts with the signed-in worker's name. "Add a worker" adds another name. A name row that is present needs a name.
3. Clearing `visit_at` is rejected. A missing key, a blank, a date with no time, or an unparseable value is 422 with message "Visit time is invalid" and `details.visit_at` of `["is invalid"]`. A missing or non-boolean `bringing_basket` is "Bringing a basket is invalid". An empty `assigned_workers` array, a missing name, or more than ten names is "Assigned worker is required" or "Assigned worker is invalid". The stored pre-visit fields stay as they were.
4. The pre-visit section shows "Aim for a visit within a week of the enrolment." When the stored `visit_at` is more than seven days after `submitted_at`, it also shows "This visit is later than a week after the enrolment." A time at exactly seven days does not show that second sentence. The `<time datetime>` is the UTC value from the API. The visible text is the browser's local zone, English, day without a leading zero, full month, year, and 24-hour time: a UTC+8 viewer of `2026-11-24T01:00:00Z` sees "24 November 2026 at 09:00". The checkbox is labeled "Bringing a basket". The names are labeled "Assigned workers".
5. Until a visit is stored, Verification Interview, Post-visit, and both mark actions are not on the page. The page says "Set the visit before recording it." The field is labeled "Visit time". The button that stores a time reads "Set visit". When a time is already stored and the case is not marked, that button reads "Change visit". The stored time keeps the label "Visit time". A later PATCH with the same instant and a different checkbox or name list returns 200, stores those fields, and queues no visit mail.

### Verification Interview

6. After a visit time is stored, the worker case shows a stage list that stays visible while a stage is open. The heading is "Verification Interview". The stages, in order, are "Who is here", "How the family formed", "A day in their life", "How they are together", "The house and the meals", and "What they need". The open stage shows "Current". A stage that has been saved shows "Saved". A stage that has not shows "Not saved". The worker opens any stage from that list. "Back" and "Next" move one stage. Stage 1 has no Back. Stage 6 has no Next. Post-visit is a section below the interview, not a stage in that list. It shows "Saved" or "Not saved".
7. Leaving a stage, by Back, Next, or the stage list, saves it when the answers are valid. Blank answers are valid. A follow-up that the answer does not open is not on the screen, and it is stored empty. An invalid answer stays on that stage, shows the error, and does not open the other stage. Typed answers are still there.
8. `PUT /enrolments/:id/verification/:stage` saves that part. `:stage` is `who_is_here`, `formation`, `daily_life`, `dynamics`, `house`, `needs`, or `boxes`. `boxes` is the post-visit assessment. Any other stage is 404. The call is rejected with "Set the visit before recording it" until `visit_at` is stored. A 200 body is the saved part plus `worker_name` and `recorded_at`. `worker_name` is the worker account's name at save time. `recorded_at` is the server time, ISO 8601 UTC. A later PUT of the same part replaces it and leaves the other parts unchanged.
9. Where the enrolment already holds a fact, the stage shows that fact above the field, labeled "Enrolment". The worker's answer is stored on the interview. The enrolment member, place, phone, and consent sentence stay as submitted. On the worker case, a stored interview answer is the account that outranks the enrolment, and the enrolment fact remains visible under it.
10. Each interview stage ends with "Anything else they said", optional text up to 2000 characters. The questions below are the field labels.

Who is here. The people already on the enrolment are listed, head first, then the other members. Saving the stage without one of those people returns 422 "Person is required" and `details.family_member_id` of `["is required"]`, and the previous stage stays as it was. The worker opens one person at a time. For each person: "Full name", "Birth date", "Gender", "Phone", "Identity", "Documents", and "Absent". The head shows "Head" and has no relationship choice. Every other person has "Relationship", one of "Spouse", "Child", "Parent", and "Other". "From where?" is on each person whose relationship is not Child, including the head. "Absent" opens "Since when" and "Why". "Add a person" adds someone the visit found, and that person needs a name before the stage can leave them on the list. An added person has "Remove". An enrolment person stays on the list and can be marked absent. "Identity" is one of "Verified", "Not verified", and "No papers", asked for each person. "Documents" is a list. "Add a document" adds one. A document has "Document" and "Number". "Document" is one of "National ID", "Social security number", "Passport", "Birth certificate", and "Other". Other opens "What document?". A document row needs a type and a number. Remove drops that document. Zero documents is allowed. The screen says "The children are the people recorded here." A child is a person whose relationship is Child. After the people, the stage asks "Does anyone else stay who is not in that list?" and "Do you have to take care of elderly parents?" Yes on the first opens "Who, and why?" Yes on the second opens "Who, and what do you do for them?"

How the family formed. "When did this family start?" and "How did it start?"

A day in their life. The same people as Who is here, one person at a time, head first. "Are you working?" and "Are you in school?" are always shown. Working and school are independent. Both may be true. Both may be false. Yes on working opens "What job?", "Ringgit per month", "Any previous jobs?", and "If you wish for a new job or income, what would that be?" "Any skills to highlight?" stays visible either way. Yes on school opens "How is school going?", "Where is school?", and "How do you get there?" The enrolment working answer, education answer, job, and rough monthly amount sit above the matching fields.

How they are together. "What does a hard week look like here?" and "When someone here needs help, who steps in?" "How are the children at home?" is on the stage when Who is here has a Child. The screen says "Write what the family said."

The house and the meals. "This place" is one of "Own", "Rent", "Staying with someone", and "Temporary". Rent opens "Rent per month" and "Are you behind on payments?" "Does it have water?" and "Does it have electricity?" stay Yes/No. "How many rooms do people sleep in?" is a number. "Is this place safe?" is Yes/No, and No opens "What feels unsafe?" "How many meals a day?" is one of "3 a day", "2 a day", "1 a day", and "Not every day". "Basket" is the basket that was taken. It is last before "Anything else they said".

What they need. The help already stored on the enrolment is listed above the field, labeled "Enrolment". Those labels are "Food", "Clothing", "School supplies", and "Help applying to a body (for example social security, welfare, or a tithe body)", and only the stored ones are listed. Then "What do you need most?", then "The family consents" and "The family does not consent", one choice. This stage has no Next.

### Post-visit

The section is titled "Post-visit". It records "Initial assessment": "Good family unit" and "Basic necessities", each checked or not, and under each a "Gap". Under Good family unit the screen says "Integrity, action, and selflessness, for the family as a whole." The screen also says "This is your judgment from the visit." Dependable generation, accumulated wealth, and the status word are not on the screen. This section is not the later F08 assessment. The mark actions are on this section. The section shows "Saved" after a successful PUT of `boxes`, and "Not saved" before that.

11. Limits, after trim. Full name is 1–200 when that person is on the list. Phone uses the enrolment phone rule and is optional. A value that fails that rule stays on the stage and shows "Enter a phone number, for example +60 12-345 6789." Birth date and "Since when" are `YYYY-MM-DD` or empty. "When did this family start?" is empty or a four-digit year from 1900 through the current calendar year. Any other year stays on the stage and shows "Enter the year, for example 2008." Gender is `male`, `female`, or `unspecified`, shown as Male, Female, and Unspecified. Relationship, for a person who is not the head, is `spouse`, `child`, `parent`, or `other`. Identity is `verified`, `not_verified`, or `no_papers`. A document `kind` is `national_id`, `social_security`, `passport`, `birth_certificate`, or `other`. Its number is 1–100 characters. `other` requires "What document?" at 1–100 characters, and any other kind stores that label empty. "This place" is `own`, `rent`, `staying_with_someone`, or `temporary`. "How many meals a day?" is `three`, `two`, `one`, or `not_every_day`. "From where?", "What job?", and "Where is school?" are 0–200. "How many rooms do people sleep in?" is empty or a JSON integer from 0 through 99. "Ringgit per month" and "Rent per month" are empty or a JSON integer from 0 through 999999999. The other questions, the gap, and "Anything else they said" are 0–2000. Yes/no answers are labeled "Yes" and "No". They and the two boxes are JSON booleans or empty while the worker is still on the section. A failed PUT does not change the stored part. An assigned worker name is 1–200.
12. Basket, when present, is 1–500 characters. This is the house-stage text, not the pre-visit checkbox. Consent, when present, is a boolean. A blank or missing required value at mark time uses the enrolment `VALIDATION_ERROR` shape. The messages are "Basket is required", "Basket is too long", "Consent is required", "Consent is invalid", "Identity check is required", "Identity check is invalid", "Relationship is required", "Relationship is invalid", "Good family unit is required", "Basic necessities is required", and "Gap is required". `details` names `basket`, `consent_given`, `identity`, `relationship`, `good_family_unit`, `basic_necessities`, and `gap`. A string past its limit is "too long", a bad type is "invalid", and a missing mark-time value is "required". `message` is the first failing field. An interview stage or the post-visit assessment that has not been saved uses message "The visit record is incomplete" and `details` of that part's key with `["is required"]`. A bad document on PUT uses "Document is invalid", "Document number is required", or "What document? is required".

### Mark

13. `POST /enrolments/:id/qualification` with `{ "outcome": "qualified" }` or `{ "outcome": "disqualified" }` is the mark. The buttons read "Mark qualified" and "Mark disqualified" and are on Post-visit. Any other outcome, or a missing outcome, is 422 "Outcome is invalid" or "Outcome is required".
14. The mark is rejected with "Set the visit before recording it" when no visit is stored. It is rejected with "The visit record is incomplete" when any interview stage or the post-visit assessment has not been saved. A saved record with the basket text blank, consent missing, a person on the saved Who is here list with no identity choice, a person on that list other than the head with no relationship, or either box missing uses that field's sentence from criterion 12. An unchecked box with a blank gap is "Gap is required". No outcome is stored and no outcome mail is queued. A missing document number does not reject the mark.
15. `qualified` is rejected with "The family has not consented" and `details.outcome` of `["needs consent"]` when consent is false. `disqualified` is allowed in that case. An identity of `not_verified` or `no_papers` does not reject either outcome. Either box may be checked or unchecked for either outcome.
16. The first mark returns 201:

```json
{
  "outcome": "qualified",
  "marked_at": "2026-11-24T02:00:00Z",
  "marker_name": "Aman"
}
```

`marker_name` is the worker's name at that moment. `marked_at` is the server time. A second mark returns 422 "The mark is already set" and `details.outcome` of `["is already set"]`. The stored outcome and `marked_at` stay.
17. After the outcome is stored, `PATCH` of the visit and `PUT` of a stage return 422 "Verification is finished". The visit time, the pre-visit fields, the interview, the post-visit assessment, and the outcome stay as they were. No further visit or outcome mail is queued.
18. The marked worker case hides "Set visit", "Change visit", "Add a worker", "Back", "Next", "Add a person", "Add a document", and both mark actions. The stage list remains. Each stage and Post-visit open as text. Qualified shows "This family is qualified." Disqualified shows "This family is disqualified."
19. The family is not deleted. The worker and the matching submitter still receive the enrolment from GET. A later enrolment is not compared with this one. The screen does not show a status word.

### Who sees it

20. Worker detail adds `visit_at`, `bringing_basket`, `assigned_workers`, `verification` (null until the first part is saved, then the six interview stages and `boxes`), `outcome` (null until the mark), `marked_at`, and `marker_name`. Worker list items add `visit_at` and `outcome` only. They do not add the interview, the checkbox, or the assigned names.
21. Submitter JSON keeps `progress.visit_at` and adds `progress.outcome`. Both are null on `POST /enrolments` and until the worker sets them. The submitter body does not include `verification`, `bringing_basket`, `assigned_workers`, the basket text, consent, the identity check, document numbers, the interview, the two boxes, `marked_at`, or `marker_name`.
22. The submitter progress page keeps "This case is in. No one has looked. No visit is set." for no looks and no visit. A stored visit uses the headline "This case is in." and the line "A visit is set for {local time}." in the same local format as the worker case. "No visit is set." remains the line when looks exist and no visit is stored. Qualified adds "This family is qualified." Disqualified adds "This family is disqualified."
23. Each row on the enrolments list shows the place, the head's name, the visit line ("A visit is set for {local time}." or "No visit is set."), and the outcome line when an outcome is stored. A row with no outcome has no outcome line. This holds for the submitter, who may have many enrolments, and for the worker.
24. At 390 CSS pixels wide, the worker case, including the stage list and an open stage, submitter progress, and the enrolments list do not require horizontal scrolling.

### Mail

25. When `email` is empty, the visit and the mark queue nothing. When `email` is present, the first stored visit time queues one message. A later PATCH that changes the instant queues another message and does not alter the earlier message's subject or body. A PATCH that stores the same instant queues nothing, including when the checkbox or the assigned names change.
26. The visit subject is "Sokong visit". The first body is "A visit is set for {head} at {place}. The visit time is {utc}." A changed time uses "The visit time for {head} at {place} is now {utc}." `{head}` is the member whose role is `head` on the enrolment. `{place}` is `place_name`. `{utc}` is the UTC time in the same English shape as the screen, with " UTC" after it. The month is the English name, including when the server locale is not English. `2026-11-24T01:00:00Z` is "24 November 2026 at 01:00 UTC".
27. The mark queues one message. The subject is "Sokong verification". Qualified body: "{head} at {place} is qualified." Disqualified body: "{head} at {place} is disqualified."
28. Neither message contains another member's name, the enroler phone, the family phone, the basket, the bringing-a-basket answer, an assigned worker's name, the identity check, a document number, or an interview answer. A look or a note queues no mail. If the queue raises, the visit or the mark stays saved and the response status stays 200 or 201.

### HTTP contract

JSON keys are snake_case. Times are ISO 8601 UTC. Ids are UUIDs. Paths are unversioned.

`PATCH /enrolments/:id/visit`, `PUT /enrolments/:id/verification/:stage`, and `POST /enrolments/:id/qualification` require a bearer token and the worker locality link used by `POST /enrolments/:id/looks`. A failed validation is 422:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The visit record is incomplete",
    "details": { "who_is_here": ["is required"] }
  }
}
```

A body larger than 128 KiB, or a chunked body, stays 413 `PAYLOAD_TOO_LARGE`.

`GET /enrolments` and `GET /enrolments/:id` keep the enrolment shapes and add the fields in criteria 20 and 21. `visit_at` is no longer forced to null once a visit is stored.

## Open Questions

None.
