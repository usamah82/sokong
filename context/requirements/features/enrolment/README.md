# Feature: enrolment

Status: in-review

The interview covers the record a phone enrolment needs: F01 Localities, F02 Accounts and roles, F03 Family unit record, F04 Enrolment, and F05 Enrolment progress. Usamah confirmed the statement in [intent.md](intent.md) on 2026-11-02 and approved [spec.md](spec.md) on 2026-11-03. The screens are in [design.md](design.md). Usamah approved [plan.md](plan.md) and [tasks.md](tasks.md) on 2026-11-03.

## Links

- Intent: [intent.md](intent.md)
- Spec: [spec.md](spec.md)
- Design: [design.md](design.md)
- Plan: [plan.md](plan.md)
- Tasks: [tasks.md](tasks.md)
- Pull requests: [#4](https://github.com/usamah82/sokong/pull/4), [#5](https://github.com/usamah82/sokong/pull/5), [#7](https://github.com/usamah82/sokong/pull/7), [#8](https://github.com/usamah82/sokong/pull/8), [#11](https://github.com/usamah82/sokong/pull/11)

## Status

Allowed values, in order: `interviewing`, `intent-confirmed`, `spec-draft`, `spec-approved`, `planning`, `plan-approved`, `implementing`, `in-review`, `done`. `parked` needs a reason written here.

Only a human sets `intent-confirmed`, `spec-approved`, `plan-approved`, or `done`.

## Review hold

Task 6 is [pull request #12](https://github.com/usamah82/sokong/pull/12), open against `feature/enrolment`, and it is not merged. `bin/ci` is green on that branch. The second code review approved it. The test gaps from the test pass are closed there. `spec.md` was not edited.

The [security audit](https://github.com/usamah82/sokong/pull/12#issuecomment-6789870018) left one High finding and two Medium findings. Fixing them would change `spec.md` or Task 6's acceptance, so the loop stopped.

- High: `POST /accounts` returns a token for the email in the body without proving the caller controls that inbox. The spec's `201` body is `token` and `account` immediately, and Task 6 accepts that shape. A later task lets the matching submitter read enrolments stored under that email. Inbox proof is a spec change.
- Medium: sign-up is unthrottled, and a duplicate email says the address is taken. The spec requires the email to be unique and a validation failure to be `422`. It sets no rate limit. Hiding whether the email exists is specified for a wrong sign-in, which is Task 7.
- Medium: the bearer token has no lifetime. The spec revokes it on `DELETE /sessions`, which is Task 7. A lifetime is not specified.
