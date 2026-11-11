# Feature: enrolment

Status: in-review

The interview covers the record a phone enrolment needs: F01 Localities, F02 Accounts and roles, F03 Family unit record, F04 Enrolment, and F05 Enrolment progress. Usamah confirmed the statement in [intent.md](intent.md) on 2026-11-02 and approved [spec.md](spec.md) on 2026-11-03. The screens are in [design.md](design.md). Usamah approved the first [plan.md](plan.md) and [tasks.md](tasks.md) on 2026-11-03. On 2026-11-11 Usamah approved the revised spec: sign-up confirms the email before sign-in, sign-up returns no token, and the account, session, and confirmation routes are rate limited. Tasks 1–5 stay done. On 2026-11-11 Usamah approved this plan. Tasks 6–27 replace the account contract. Task 6 is [pull request #13](https://github.com/usamah82/sokong/pull/13) and it is not merged. [Pull request #12](https://github.com/usamah82/sokong/pull/12) must not merge.

## Links

- Intent: [intent.md](intent.md)
- Spec: [spec.md](spec.md)
- Design: [design.md](design.md)
- Plan: [plan.md](plan.md)
- Tasks: [tasks.md](tasks.md)
- Pull requests: [#4](https://github.com/usamah82/sokong/pull/4), [#5](https://github.com/usamah82/sokong/pull/5), [#7](https://github.com/usamah82/sokong/pull/7), [#8](https://github.com/usamah82/sokong/pull/8), [#11](https://github.com/usamah82/sokong/pull/11), [#13](https://github.com/usamah82/sokong/pull/13)

## Status

Allowed values, in order: `interviewing`, `intent-confirmed`, `spec-draft`, `spec-approved`, `planning`, `plan-approved`, `implementing`, `in-review`, `done`. `parked` needs a reason written here.

Only a human sets `intent-confirmed`, `spec-approved`, `plan-approved`, or `done`.

## Review stop

Task 6 is [pull request #13](https://github.com/usamah82/sokong/pull/13), open against `feature/enrolment`, and it is not merged. `bin/ci` was green before the pull request opened. The code review's Required finding, feature status `in-review` while later tasks remain, is fixed on that branch. Optional and Nit were left. The review asked for a security pass and not for a test or performance pass.

The [security audit](https://github.com/usamah82/sokong/pull/13#issuecomment-6799737768) left one High finding. Fixing it would change `spec.md` criterion 21. The spec was not edited.

- High: `POST /accounts` stores the first caller's password. Criterion 21 and Task 7 keep that password when the same unconfirmed email signs up again within 24 hours, and confirming the link would make that password the one that can sign in. The audit says a repeat unconfirmed sign-up must replace the digest, including inside 24 hours. That is a spec change. This pull request's rule, any existing email returns 422, stays as Task 6 wrote it.
