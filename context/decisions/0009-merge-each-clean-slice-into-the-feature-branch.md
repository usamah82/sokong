# ADR-0009: Merge each clean slice into the feature branch

## Status

Accepted

## Date

2026-11-04

## Context

ADR-0008 merges a feature's pull request once, after every task and checkpoint is checked. The rejected alternative was merging after every clean slice, because that would put an unfinished feature on the default branch.

The default branch is `main`. A feature branch is the line for that feature. Usamah wants a finished task on the feature branch before the next task starts, and wants `main` to stay a human merge. One task is one slice.

Enrolment already has tasks 1 and 2 on `cursor/record-product-answers`, through the merge of pull request #5. The open Task 3 work is on `feature/enrolment-records`.

## Decision

Each feature has one long-lived branch, `feature/<slug>`. Each task is a short-lived branch and a pull request into that branch. The branch name for a new slice is `feature/<slug>-<task number>`. An in-flight slice keeps the branch it already has.

A review with no findings merges that slice's pull request into `feature/<slug>` with a merge commit. The branch is not deleted. The next session then implements the next unchecked task from the updated feature branch. The loop does not wait for a human between tasks.

When required checks are still running, the review hop enables auto-merge and sets status to `in-review`. When the slice pull request is merged and a later task or checkpoint remains, the following hop sets `implement` and status `implementing`. When the slice pull request is merged and nothing remains, that hop sets `done`.

The loop does not open or merge a pull request into `main`. The human merges `feature/<slug>` to `main`.

A `spec-stop` does not merge. A red required check follows the ADR-0008 rule: `fix` on the first two rounds when the failure is a test or lint the spec already requires, otherwise `spec-stop`.

Create `feature/<slug>` from `main` when the feature has no merged slice yet. When earlier slices already landed somewhere else, the feature README names that start. Enrolment's `feature/enrolment` starts at `cursor/record-product-answers` as of pull request #5. Pull request #6 merges into `feature/enrolment`.

## Alternatives Considered

### Keep one pull request open until every task is checked

- Pros: `main` and the feature branch both stay free of a partial feature
- Cons: a finished task waits on later tasks, which is the wait Usamah removed
- Rejected: the feature branch is allowed to hold a feature that still has tasks left

### Merge each clean slice to main

- Pros: `main` receives each task as its review finishes
- Cons: `main` then contains an unfinished feature, which is the outcome ADR-0008 refused
- Rejected: `main` stays a human merge of the finished feature branch

## Consequences

- ADR-0009 supersedes the merge-once rule in ADR-0008. ADR-0008 still supplies the merge commit and the red-check rule.
- `repo-workflow`, the prompts, the operating model, the how-to, the feature template, and the enrolment README state this.
- `in-review` means the slice pull request's auto-merge is queued. `done` means every task and checkpoint is on `feature/<slug>`.
- The human gates that stay are intent, spec, plan, a spec-stop, the merge of `feature/<slug>` to `main`, and deploy.
