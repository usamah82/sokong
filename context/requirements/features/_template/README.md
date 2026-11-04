# Feature: <slug>

Status: interviewing

Copy this folder to `context/requirements/features/<slug>/` before filling it in. Do not treat `_template` as a feature.

## Links

- Intent: [intent.md](intent.md)
- Spec: [spec.md](spec.md)
- Plan: [plan.md](plan.md)
- Tasks: [tasks.md](tasks.md)
- Handoff: handoff.md (the build loop writes this after plan approval)
- Pull requests:

## Status

Allowed values, in order: `interviewing`, `intent-confirmed`, `spec-draft`, `spec-approved`, `planning`, `plan-approved`, `implementing`, `in-review`, `done`. `spec-stop` halts the build loop from `implementing`. `parked` needs a reason written here.

Only a human sets `intent-confirmed`, `spec-approved`, or `plan-approved`. An agent sets `spec-stop` when a review finding needs a changed spec, a changed task, or a new ADR. An agent sets `in-review` when a slice pull request's auto-merge is queued, and `done` when every task and checkpoint is on `feature/<slug>` (ADR-0009). The human merges that branch to `main`.

## Build loop

After `plan-approved`, one fresh session does one hop and stops (ADR-0007). The procedure is the build loop in `.cursor/skills/repo-workflow/SKILL.md`. The prompt is `Continue the build loop` in `context/workflow/prompts.md`. `handoff.md` and `review.md` live in this folder once the loop has started.
