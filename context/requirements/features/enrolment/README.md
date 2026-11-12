# Feature: enrolment

Status: implementing

The interview covers the record a phone enrolment needs: F01 Localities, F02 Accounts and roles, F03 Family unit record, F04 Enrolment, and F05 Enrolment progress. Usamah confirmed the statement in [intent.md](intent.md) on 2026-11-02 and approved [spec.md](spec.md) on 2026-11-03. The screens are in [design.md](design.md). Usamah approved the first [plan.md](plan.md) and [tasks.md](tasks.md) on 2026-11-03. On 2026-11-11 Usamah approved the revised spec: sign-up confirms the email before sign-in, sign-up returns no token, and the account, session, and confirmation routes are rate limited. Tasks 1–5 stay done. On 2026-11-11 Usamah approved this plan. Tasks 6–27 replace the account contract. On 2026-11-11 Usamah changed criterion 21: a repeat sign-up for an unconfirmed email replaces the password and invalidates the previous confirmation token, however recent the account is. A confirmed email still returns 422 and its password does not change. Nothing in that change is waiting. Task 6 landed in [pull request #13](https://github.com/usamah82/sokong/pull/13). Task 7 landed in [pull request #14](https://github.com/usamah82/sokong/pull/14). Task 8 landed in [pull request #15](https://github.com/usamah82/sokong/pull/15). Task 9 landed in [pull request #17](https://github.com/usamah82/sokong/pull/17). Task 10 landed in [pull request #18](https://github.com/usamah82/sokong/pull/18). The checkpoint after tasks 8–10 is checked. Task 11 landed in [pull request #19](https://github.com/usamah82/sokong/pull/19). Task 12 landed in [pull request #20](https://github.com/usamah82/sokong/pull/20). [Pull request #12](https://github.com/usamah82/sokong/pull/12) was closed on 2026-11-12. It carried the old sign-up contract that returns a token. The revised contract is already on this branch.

## Links

- Intent: [intent.md](intent.md)
- Spec: [spec.md](spec.md)
- Design: [design.md](design.md)
- Plan: [plan.md](plan.md)
- Tasks: [tasks.md](tasks.md)
- Pull requests: [#4](https://github.com/usamah82/sokong/pull/4), [#5](https://github.com/usamah82/sokong/pull/5), [#7](https://github.com/usamah82/sokong/pull/7), [#8](https://github.com/usamah82/sokong/pull/8), [#11](https://github.com/usamah82/sokong/pull/11), [#13](https://github.com/usamah82/sokong/pull/13), [#14](https://github.com/usamah82/sokong/pull/14), [#15](https://github.com/usamah82/sokong/pull/15), [#17](https://github.com/usamah82/sokong/pull/17), [#18](https://github.com/usamah82/sokong/pull/18), [#19](https://github.com/usamah82/sokong/pull/19), [#20](https://github.com/usamah82/sokong/pull/20)

## Status

Allowed values, in order: `interviewing`, `intent-confirmed`, `spec-draft`, `spec-approved`, `planning`, `plan-approved`, `implementing`, `in-review`, `done`. `parked` needs a reason written here.

Only a human sets `intent-confirmed`, `spec-approved`, `plan-approved`, or `done`.
