# Review

Task: Task 3: Accept an enrolment over HTTP
Base: 2e7b9859ae9cfc635b29aa5fa8660fc7bf8f8057
Verdict: fix

## In scope

The slice matches the task acceptance that is already tested: anonymous `POST /enrolments` returns the 201 shape, stores null coordinates, ignores a client consent sentence, and the listed invalid bodies return `422` with `VALIDATION_ERROR` and save nothing. Invalid input does not reach `Enrolment.record!`. Queries stay parameterized. No auth check belongs on this route.

These spec rules are implemented and not locked by a test. Add each case to `backend/test/integration/enrolments_test.rb`. Each rejection saves no enrolment, family, member, or locality.

- Spec record 17: latitude and longitude are numbers. `backend/app/models/enrolment_submission.rb` rejects a non-numeric value in `check_coordinate`. Inverting `is_a?(Numeric) && finite?` to `||` left `test/integration/enrolments_test.rb` green (25 runs, 0 failures). A string latitude with a numeric longitude, and a string longitude with a numeric latitude, must return `422`.
- Spec record 14: gender is required. A blank gender must return `422`. The suite only sends a gender outside the three values.
- Spec record 12: member name 1–200, description up to 2000, and job up to 200. A head name of 201 characters, a description of 2001, and a job of 201 while working must return `422`.
- Spec record 13: a present monthly amount is an integer from 0 through 999999999. `1000000000` while working must return `422`.
- Spec HTTP shape: members are head first, then submission order. Post a non-head member before the head and assert the `201` lists the head first. Reversing `response_body`'s member list stays green today.
- The approved plan requires exactly one head. A members array whose only role is `member` must return `422` and save nothing. Zero members and two heads are already tested; this branch is not.
