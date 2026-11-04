# Feature: enrolment

Status: implementing

The interview covers the record a phone enrolment needs: F01 Localities, F02 Accounts and roles, F03 Family unit record, F04 Enrolment, and F05 Enrolment progress. Usamah confirmed the statement in [intent.md](intent.md) on 2026-11-02 and approved [spec.md](spec.md) on 2026-11-03. The screens are in [design.md](design.md). Usamah approved [plan.md](plan.md) and [tasks.md](tasks.md) on 2026-11-03. The long-lived branch is `feature/enrolment`. It starts where pull request #5 merged, on `cursor/record-product-answers`, so tasks 1 and 2 are already there. Pull request #6 is the Task 3 slice into `feature/enrolment` (ADR-0009).

## Links

- Intent: [intent.md](intent.md)
- Spec: [spec.md](spec.md)
- Design: [design.md](design.md)
- Plan: [plan.md](plan.md)
- Tasks: [tasks.md](tasks.md)
- Handoff: [handoff.md](handoff.md)
- Pull requests: [#4](https://github.com/usamah82/sokong/pull/4), [#5](https://github.com/usamah82/sokong/pull/5), [#6](https://github.com/usamah82/sokong/pull/6)

## Status

Allowed values, in order: `interviewing`, `intent-confirmed`, `spec-draft`, `spec-approved`, `planning`, `plan-approved`, `implementing`, `in-review`, `done`. `spec-stop` halts the build loop from `implementing`. `parked` needs a reason written here.

Only a human sets `intent-confirmed`, `spec-approved`, or `plan-approved`. A clean review merges the slice into `feature/enrolment` and the next session takes the next task (ADR-0009). You merge `feature/enrolment` to `main`. The next session uses `Continue the build loop` in `context/workflow/prompts.md`.
