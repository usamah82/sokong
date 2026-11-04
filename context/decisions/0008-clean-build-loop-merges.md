# ADR-0008: A clean build loop merges its pull request

## Status

Accepted

## Date

2026-11-04

## Context

ADR-0007 stops a finished loop at `in-review` and waits for a human to merge. That wait is another paste. The review hop is a fresh session, and it did not write the code. When its verdict is `ready`, every task and checkpoint is checked, the re-review after any fixes found nothing, and the change matches the approved spec.

Pull request #4 merged with a merge commit. The repository allows merge commits, squash, and rebase.

## Decision

The review hop that reaches `ready` merges the open pull request for the current branch. The merge is a merge commit. It does not delete the branch.

It merges only when every task and checkpoint is checked and this review found nothing in scope. A clean review that still has a later task sets `implement` and does not merge. It does not merge on `spec-stop`.

Required checks must be green, or still running. When they are still running, the hop enables auto-merge and leaves status `in-review`, with handoff action `ready` and note `auto-merge queued`. When a required check is failing, the hop does not merge. It sets `fix` when `Fix-round` is `0` or `1` and the failure is a red test or lint for behavior the spec already requires. Otherwise it sets `spec-stop` and names the check in `Note`.

When the pull request is merged, the hop sets status `done`. A later hop that finds `in-review` and a merged pull request sets `done` and stops. A later hop that finds auto-merge queued and checks still pending stops.

Human gates that stay: confirm intent, approve the spec and its design screens, approve the plan, resolve a spec-stop, deploy.

## Alternatives Considered

### The human still clicks merge

- Pros: a person sees the pull request one last time
- Cons: the click adds no judgment after a clean `ready` review
- Rejected: that is the wait this decision removes

### Merge after every clean slice

- Pros: the default branch receives each slice as its review finishes
- Cons: later tasks in the same approved plan are not on that branch yet, so the default branch gains an unfinished feature
- Rejected: the loop merges once, when no task or checkpoint remains

### Squash the branch

- Pros: one commit on the default branch
- Cons: pull request #4 kept the slice commits via a merge commit
- Rejected: stay with a merge commit

## Consequences

- ADR-0007's human merge no longer applies. `repo-workflow` is the procedure.
- `in-review` means auto-merge is queued and the pull request is not merged yet. `done` means the pull request is merged.
- An agent may set `done` only by this rule. Deploy stays a separate human request.
- The runner stays quiet on `spec-stop` and `done`.
- The runner is the Cursor automation "Sokong build loop" on `usamah82/sokong`. It starts on a pull request push, on checks finishing, and on merge. The first hop, and a claimed hop, still start from the continue prompt.
