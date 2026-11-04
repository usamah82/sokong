# Spec

Status: spec-approved

Catalog rows F01–F05 are in this feature only for the slice below. [intent.md](intent.md) stays the confirmed intent. This file says what "done" means.

## Objective

A person with a phone can enrol a family, for themselves or for someone else, without creating an account first. The saved record tells a community worker who the family is, where they are, how to find them, and what help they are asking for. A submitter who later signs up with the optional email can see that the case is in, who has looked, what those people said, and that no first visit is set.

The submitter may be the family, a community member, a community worker, or anyone else. The other user is the community worker who has to contact the family.

Sokong cannot take an enrolment today. A visit, an assessment, and any help wait on this record.

This is one capability: submit that enrolment and read its progress. It is not five separate products.

Choices approval accepts:

- The phone surface is a Nuxt app in `web/`. Flutter is a later spec. The API is the contract that later client will use.
- The suggested district is the nearest locality Sokong already stores a center for. This feature does not call a map provider.
- The API keeps a device point only when the place name matches the nearest locality that already has a center. Any other name drops the point, because that place may not be where the phone is.
- A locality matches by normalized name, and by a circle when a worker has set a center and a radius. An enrolment-created locality stores the typed name and no center. A worker sets the center and the radius. Until some locality has a center, the phone cannot suggest a district.
- When several localities fit and the submission has a point, the closest is the shortest distance from that point to a locality center. When the submission has no point, distance cannot be computed: after the worker rule below, the earliest created locality is used.
- The enroler's contact is a required phone number. The optional family phone uses the same phone rule. On self-enrolment the family phone starts as the enroler's phone, and the submitter can change or clear it. On behalf, the family phone starts empty.
- The form is four stages: enroler, family and head, other members, then remarks for the community worker. The API still receives one enrolment.
- Help may be left blank. The worker then sees that no help was named.
- Gender is Male, Female, or Unspecified. Job is free text. Age and the rough monthly amount are integers. A blank age or a blank amount is stored as empty. No currency code is collected.
- The public sign-up form creates a submitter account only. An operator command creates a community worker and links a locality.
- The first time a worker opens one enrolment, that look is stored. A note is a later action on that case. Nothing in this feature sets the first visit time.
- When an email address was given, one invitation is queued. The enrolment is saved even if mail is down. Later progress sends no mail.

A locality fits the submission when the normalized place name equals the locality name, or when the kept point lies inside the locality's circle (distance to the center less than or equal to `radius_metres`). Among the localities that fit, one that has a community worker wins over one that has none. If several in that pool have a numeric distance, the shortest distance wins. Equal distance, or no point to measure, uses the earliest `created_at`. A fitting locality with no center is ordered after every fitting locality that has a numeric distance.

Assignment happens when the enrolment is created. Renaming a locality or editing its circle does not move enrolments already saved.

Each enrolment creates one family unit. The head and the other members belong to that unit. The source of every fact on the form is the enroler, marked self or on behalf.

## Tech Stack

- Rails 8.1 API in `backend/`, Ruby 3.4.11, SQLite for local and test databases. Module name `Backend`. URL paths stay unversioned (ADR-0003).
- Nuxt app in `web/`, a sibling of `backend/` (ADR-0005). Dev server port `3001` so it does not take Rails' port `3000`.
- User-facing copy is externalized with [`@nuxtjs/i18n`](https://i18n.nuxtjs.org/docs/getting-started). `defaultLocale` is `en`. The only locale file is `web/i18n/locales/en.json`. Routing strategy is `no_prefix` while English is the only locale (ADR-0006).
- Auth is an opaque bearer token issued by the API. `has_secure_password` (bcrypt, already named in the Rails Gemfile) stores the password. No JWT library and no third-party auth service.
- Mail uses Action Mailer and Active Job, which are already in the API. The test suite uses the test delivery adapter.
- CORS allows `http://localhost:3001` only. A production origin waits until a host is decided.
- `GET /up` stays as it is.

## Commands

Repository gate, from the root. This feature extends it so the web test and lint scripts run after the Rails gate:

```bash
bin/ci
```

API:

```bash
cd backend
bundle install
bin/rails db:prepare
bin/rails server
bin/rails test test/integration/enrolments_test.rb
```

The server listens on port `3000`.

Web, after the app exists:

```bash
cd web
npm install
npm run dev -- --port 3001
npm test
npm run lint
```

Operator commands, from `backend`. They are not HTTP routes. `sokong:worker` and `sokong:locality` fail if that email or that new row cannot be created. `sokong:locality` prints the new locality id. `sokong:assign` links the account to that id and succeeds again if the link is already there. It fails if the email or the id is unknown.

```bash
cd backend
bin/rails sokong:worker EMAIL=aman@example.com NAME="Aman" PASSWORD="a long passphrase"
bin/rails sokong:locality NAME="Block 4"
bin/rails sokong:assign EMAIL=aman@example.com LOCALITY_ID=<id printed above>
```

`PASSWORD` is at least 12 characters. `NAME` is the worker name shown on progress.

## Project Structure

API behavior stays in Rails. Domain rules for claiming a locality live on a model or one plain object under `backend/app/`, called by a thin controller.

```
backend/app/models/         Account, Locality, LocalityAssignment,
                            FamilyUnit, FamilyMember, Enrolment, Look
backend/app/controllers/    enrolments, accounts, sessions, localities
backend/app/mailers/        the one invitation
backend/lib/tasks/          sokong:worker, sokong:locality, sokong:assign
backend/test/integration/   the HTTP cases in Testing Strategy
web/                        Nuxt app this spec introduces
web/i18n/locales/en.json    every user-facing string
web/pages/                  four-stage enrolment wizard, confirmation,
                            sign-up, sign-in, submitter progress, worker cases,
                            locality boundary
```

The web app talks only to the HTTP contract in Success Criteria. Flutter is not created.

## Code Style

Rails follows `rubocop-rails-omakase` and `.cursor/rules/rails-api.mdc`. Web copy is read through the i18n module, including the consent sentences, the location sentences, errors, and empty states.

The locality tie-break is not written in the controller:

```ruby
class Locality < ApplicationRecord
  def self.claim(place_name:, point:)
    matches = fitting(place_name, point)
    return create_from_submission!(place_name) if matches.empty?

    staffed = matches.select(&:staffed?)
    closest(staffed.empty? ? matches : staffed, point)
  end
end
```

`staffed?` means at least one community worker is linked. `create_from_submission!` stores the typed place name and no center. A kept point is only an input to `fitting`.

## Testing Strategy

`bin/ci` is the gate. Rails integration tests prove the HTTP contract, the fit rule, auth, and the invitation. Vitest component tests prove the wizard: the four stages in order, back keeps what was typed, self-enrolment copies the enroler phone into the family phone until that copy is edited, on-behalf leaves the family phone empty, gender offers only Male, Female, and Unspecified, age accepts only an integer or a blank, and the long-text fields are textareas of at least three lines. A browser pass at 390 CSS pixels wide checks each wizard stage, the confirmation, submitter progress, and the worker case. Those pages scroll vertically and do not scroll horizontally.

Edge cases the integration tests cover:

- Family phone, how to find them, help, description, age, gender, job, and monthly amount all empty, with one named head. The enrolment is saved. No locality and no worker existed. A new locality holds it.
- Missing enroler phone, a contact that is not a phone, missing place name, missing head name, a gender outside the three values, a non-integer age, a non-integer monthly amount, zero members, two heads, or more than 20 members. The response is 422 and nothing is saved.
- A body larger than 128 KiB, or a chunked body, is 413 with `PAYLOAD_TOO_LARGE` and nothing is saved.
- A place name that matches no locality creates one. A place name that matches one uses it.
- A kept point inside several circles, at least one of those localities staffed: the closest staffed locality.
- A kept point inside several circles, none staffed: the closest.
- Equal distance, or several name matches and no kept point: the earliest `created_at` after the staffed filter.
- A fitting locality with no center loses to a fitting locality with a numeric distance.
- Coordinates whose place name matches the nearest locality are stored on the enrolment. Any other name drops them. A locality created by the enrolment has no center.
- Self and on-behalf each store their own consent sentence.
- Email present enqueues one invitation and no family details in that mail. A mail failure still leaves the enrolment saved. No email enqueues nothing.
- A look or a note enqueues no mail.
- Sign-up is not required to submit. Public sign-up cannot create a worker, including by sending a role field.
- The matching submitter sees the case in, an empty look list, and no visit. Another account, a worker of another locality, and an anonymous caller do not get the record.
- The worker of the locality sees the members, the place, how to find them, the family phone, the enroler contact, and the help asked.
- The worker's first open of that enrolment stores one look. A second open does not store another. A note shows on the submitter's progress. `visit_at` stays empty.
- Editing a locality name or circle does not move an enrolment already saved.
- `GET /up` still returns success.

## Boundaries

Left for later features:

- The verification visit, including setting the first visit time, the basket, the identity check, and the story the form could not hold.
- The four checkboxes, status words, and qualifying or disqualifying a case.
- Giving help, recording that help was given, and offers from benefactors.
- Mail on later progress. The single invitation at submit time is in this feature.
- Accounts for benefactors, facilitators, and planners, and public sign-up as a community worker.
- A person in more than one family unit, moving between units, merging units, and an institution flag. A unit of one person is the head alone.
- How members are related beyond head or other member.
- Duplicate detection, scam matching, and registrations from other organizations.
- Retention rules, a privacy request, and rate limits or captchas. Hosting is still undecided.
- Polygon boundaries, a map provider, and a gazetteer of official districts.
- The Flutter app, a production origin, and a production database.
- Reassigning an enrolment when a locality's name or circle changes later.

Always:

- Run `bin/ci` before a code change is called done.
- Validate input at the controller. Keep the fit rule in the model or one plain object.
- Keep user-facing strings in `web/i18n/locales/en.json`.
- Keep enroler contact, family phone, email, place name, how to find them, other help, coordinates, and member name, description, job, and monthly amount out of the request log.
- Return 404 when an account must not see a record, including when the id does not exist, so the response does not reveal that a family is on file.
- Leave `config/master.key` and `storage/` uncommitted.

Ask first:

- A new gem or npm dependency beyond bcrypt (already in the Gemfile), `@nuxtjs/i18n`, and the Vitest setup the web tests need.
- Opening CORS to any origin other than `http://localhost:3001`.
- A map provider, a gazetteer, or a second client.
- Changing `GET /up` or versioning a URL.

Never:

- Reject an enrolment because no worker, no locality, no family phone, or no account exists, or because the family looks ineligible.
- Put the device point on the family after the submitter named a different place.
- Send family names, place, phone, contact, or help in the invitation email.
- Expose worker creation or locality assignment as a public route.
- Commit secrets, edit vendored skills, or drop a failing test to make the gate green.

## Success Criteria

### Form

The enrolment form is a wizard of four stages. Back and Next move one stage. Typed values stay when the submitter goes back. The step indicator shows the stage number and name. Submit is available only on stage 4. The API is still one `POST /enrolments` of the whole form.

1. Stage 1, "Who is enrolling", collects the mode and the enroler. The two choices are "This is my family" and "I am enrolling this family for them". "This is my family" is selected when the form opens. The sentence under the choice changes before the submitter leaves the stage.
   - Self: "Submission means the family consents. That consent is confirmed at the verification visit."
   - On behalf: "This case is valid and will be checked at a visit. It may not be enrolled unless the family consents then."
   The enroler's contact is a phone number, required before Next. The optional email sits on this stage.
2. The saved enrolment stores `on_behalf` and the exact sentence shown.
3. Stage 2, "The family", collects the place, the optional family phone, and the head. Required before Next: place name, and a head with a non-blank name. The head fields on this stage are name, Age, Gender, description, in education, working, and, when working, job and the rough monthly amount. A control labeled "Use my current location" asks the device for a point. When a nearest locality with a center exists, the place field fills with its name and the screen says "This place was suggested from your current location." The screen also says "You can name a different place if you are not with the family." Changing the place name removes the suggested-from-location sentence. When the device returns a point and no locality has a center, the screen says "Your current location was read. Name the place." Refusing the device, or never using the control, still allows Next once a place name is typed.
4. When the mode is self and the family phone is still the automatic copy, stage 2 shows the enroler's phone in the family phone field. Editing or clearing the family phone stops the copying. Changing the enroler phone while the copy is still automatic updates the family phone. Switching to on behalf clears the family phone only while it is still that automatic copy. On behalf, the family phone starts empty. The stored family phone is whatever the field holds at submit, including empty.
5. Stage 3, "Other people in the family", collects any other members. Zero other members is valid, and Next is available immediately. Each member block that is added has the same fields as the head, including Age and Gender, and needs a non-blank name before Next. Added members can be removed. The head is not on this stage. The submitted list holds at most 20 members, including the head.
6. Stage 4, "Notes for the community worker", collects how to find them, the help choices, and a help that is not in the list. All of these may be empty. Description, how to find them, and the other-help field are textareas of at least three lines. Typed text stays on screen. Submit on this stage sends the enrolment.
7. Optional, and legal when empty: family phone; how to find them; help; other help; and for each member age, description, job, and monthly amount. Gender is one of Male, Female, or Unspecified, and the control starts on Unspecified. In education and working are independent. Both may be true. Both may be false.
8. Job and monthly amount are stored only when that member is working. When working is false, those two values are discarded.
9. Help choices are Food, Clothing, School supplies, and Help applying to a body (for example social security, welfare, or a tithe body). Any subset may be selected. A separate field accepts a help that is not in that list. No selection and a blank other-help field saves, and the worker sees that no help was named.
10. After a successful submit the screen says the case is in and that no visit is set. If an email was entered, it also says to sign up with that email to see who has looked and whether a visit is set. The enrolment exists before any account does.
11. At 390 CSS pixels wide, each wizard stage, the confirmation, progress, and the worker case do not require horizontal scrolling.

### Records

12. The enroler's contact and, when present, the family phone are phone numbers. Spaces, hyphens, dots, and parentheses are removed, and the remainder must match `^\+?[0-9]{8,15}$`. The stored value is that remainder. `+60 12-345 6789` and `012-345 6789` pass. `Mary at the shop`, `123`, and `phone: 0123456789` fail with 422 and nothing is saved. Other limits, after trim: place name 1–200; email up to 254 and a valid address when present; how to find them up to 2000; other help up to 500; member name 1–200; description up to 2000; job up to 200. Blank optional strings are stored as empty. The members list holds at most 20 people, including the head. A longer list is 422 and nothing is saved.
13. Age is an integer field on the head and on every other member. A blank age is stored as null. A present age is a JSON integer from 0 through 130. The rough monthly amount is the same kind of field, shown only when that member is working. A blank amount is stored as null. A present amount is a JSON integer from 0 through 999999999. A decimal, a numeric string such as "about 800", or any other type is 422 and nothing is saved. When working is false, a sent amount is discarded and does not fail validation.
14. Gender is required on the head and on every other member and is only `male`, `female`, or `unspecified`, shown as Male, Female, and Unspecified. Any other value is 422 and nothing is saved.
15. Place names match after trim, Unicode case fold, and collapsing internal whitespace. The stored place name keeps the submitter's casing.
16. Help keys are only `food`, `clothing`, `school_supplies`, and `help_applying`. Any other key is 422. Duplicates are stored once.
17. Latitude and longitude are both present or both absent. Latitude is a number from -90 to 90. Longitude is a number from -180 to 180. One without the other is 422 and nothing is saved. When both are present, the API keeps them on the enrolment only if the place name matches the nearest locality that has a center. Otherwise it discards them and matches the place name on its own. The response reports `latitude` and `longitude` as null when the point was discarded. A locality created here has a null center and a null radius.
18. The suggestion endpoint returns only the nearest locality name, or none. It does not return workers, radii, or enrolments. Ties use the earliest `created_at`. There is no distance cutoff.
19. A worker linked to a locality can set its name, its center, and `radius_metres` from 1 through 200000. A radius without a center is 422. Clearing the radius is allowed. A submitter or a worker of another locality receives 404.
20. Two submissions create two enrolments and two family units.

### Accounts and progress

21. `POST /accounts` creates a submitter. Password and confirmation must match. Password length is at least 12. The email is unique case-insensitively. A wrong sign-in returns 401 without saying whether the email exists.
22. Sign-in returns an opaque token. Later calls send `Authorization: Bearer <token>`. Sign-out revokes it. The web client keeps the token in `sessionStorage`.
23. A submitter sees enrolments whose stored email matches the account email, case-insensitively, and no others. With no looks, the screen says "This case is in. No one has looked. No visit is set."
24. Opening a worker's list does not record a look. The first authorized detail read by that worker records one look with the worker's name, the time, and an empty note. A note is `POST` with non-blank text up to 2000 characters and appends a new look. The submitter sees looks in time order.
25. `visit_at` is null on every enrolment this feature creates or updates.
26. The invitation subject is "Sokong enrolment". The body is "An enrolment was received. Sign up with this email address to see whether anyone has looked and whether a visit is set." It is queued at most once, only when an email was submitted.
27. A worker with no linked locality sees "No locality is linked to this account." A linked worker with no enrolments sees "No enrolments yet."
28. Anonymous detail and list requests return 401. An authenticated request for a record that account must not see returns 404 with `NOT_FOUND` and no further detail. Validation failures return 422 with this shape:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Enroler contact is required",
    "details": { "enroler_contact": ["is required"] }
  }
}
```

### HTTP contract

JSON keys are snake_case. Times are ISO 8601 UTC. Ids are UUIDs. Paths are unversioned. List responses are the full set the account may see, newest enrolment first.

`GET /localities/suggestion?latitude=&longitude=` is anonymous. `200` with `{ "locality": null }` or `{ "locality": { "name": "Block 4" } }`. The body has no other keys. A missing coordinate, a value that is not a number, or a value outside -90 through 90 and -180 through 180 returns `422` with `VALIDATION_ERROR` and the same coordinate messages as `POST /enrolments`.

`POST /enrolments` is anonymous. `201` returns the saved enrolment: id, `submitted_at`, `on_behalf`, `consent_text`, `enroler_contact`, `email`, `place_name`, `latitude`, `longitude`, `family_phone`, `how_to_find`, `help`, `other_help`, `locality` (`id`, `name`), `members` (head first, then submission order, with the member fields), and `progress` (`case_in` true, `looks` `[]`, `visit_at` null). A later anonymous `GET` of that id is 401. A body larger than 128 KiB, or a body sent with chunked transfer encoding, is `413`:

```json
{
  "error": {
    "code": "PAYLOAD_TOO_LARGE",
    "message": "Payload is too large",
    "details": {}
  }
}
```

`POST /accounts` with `email`, `password`, `password_confirmation`. `201` returns `token` and `account` (`id`, `email`, `role`). Role is `submitter`.

`POST /sessions` with `email` and `password`. `200` returns the same token payload. `DELETE /sessions` with a valid token returns `204` and revokes it.

`GET /enrolments` and `GET /enrolments/:id` require a token. A submitter's detail is the `201` shape plus looks (`id`, `worker_name`, `looked_at`, `note`). A worker's list items are `id`, `submitted_at`, `place_name`, `head_name`, `enroler_contact`, `on_behalf`, and `locality` (`id`, `name`). A worker's detail adds the family fields, `email`, `how_to_find`, `family_phone`, `help`, `other_help`, `consent_text`, coordinates when stored, `members`, and `looks`. The first worker detail read for that pair creates the empty-note look before the response is sent.

`POST /enrolments/:id/looks` with `{ "note": "Called the enroler, no answer" }` is worker-only for a locality they are linked to. `201` returns the look. A submitter receives 404.

`PATCH /localities/:id` with `name`, `latitude`, `longitude`, and `radius_metres` is worker-only for a linked locality. `200` returns `id`, `name`, `latitude`, `longitude`, and `radius_metres`.

## Open Questions

None.
