# ADR-0007: After plan approval, short sessions run the build loop

## Status

Accepted

## Date

2026-11-04

## Context

After a plan is approved, the human pastes an implement prompt, then a review prompt, then a fix prompt, then the next task. Those pastes add no product judgment. The review prompt also stops at a report, so a fix the spec already requires waits on the human too.

Running that whole loop in one chat removes the paste and removes the fresh context. The session that wrote the code then reviews it, and later tasks run in a long, worse context. ADR-0001 rejected one lifecycle agent for that reason.

The gates that still need a person are intent, spec, plan, a real change to that spec or plan, merge, and deploy.

## Decision

Once status is `plan-approved`, the remaining tasks run as a build loop. Each hop is a new session. It does one job, writes `context/requirements/features/<slug>/handoff.md`, commits that file, and stops. It does not start the next hop. It does not spawn another agent.

`handoff.md` is the only instruction the next session needs. It names the slug, the action, the task, the base commit, and the cycle count. It does not summarize the spec or the implementation chat. A review hop reads `spec.md`, `tasks.md`, and the diff from the base commit.

Actions:

| Action | The session does | Then it sets |
|---|---|---|
| `implement` | One green slice of the named task, or the next unchecked task. `bin/ci` passes. | `review` |
| `review` | Classify the diff. Write findings in `review.md`. Do not edit product code. | `fix`, `implement`, `spec-stop`, or `ready` |
| `fix` | Apply only the in-scope findings for this slice. `bin/ci` passes. | `review` |
| `spec-stop` | Stop. | — |
| `ready` | Set status to `in-review`. | — |

A finding is in scope when the approved spec and tasks already require the remedy. A finding is a spec-stop when the remedy needs a changed spec sentence, a changed task or acceptance criterion, or a new ADR. If the session cannot tell which of those it is, it is a spec-stop.

One green slice per session. A task that needs another slice sets `implement` again, with `continue` and a note of what is left. Same-slice fix rounds stop at two. The third round is a spec-stop with reason `not converging`.

The first commit of a hop claims the handoff (action plus the new base) before product code changes, so a second runner that read the old file stops.

Status stays `implementing` during the loop. `in-review` means every task is checked, the last review found nothing in scope, and the pull request is waiting on a human merge. Add `spec-stop` to the status list: the loop is halted until a human changes the spec or tasks, or tells the loop to continue.

The runner sits outside the agent. It opens one fresh session from the committed handoff. It stays quiet when the action is `spec-stop` or the status is `in-review`. It does not skip spec or plan approval. Until that runner exists, the human pastes one standing line into a new chat: continue the build loop for `<slug>`. That line carries no judgment.

On acceptance, state this loop in `repo-workflow`, `context/workflow/prompts.md`, `context/workflow/operating-model.md`, `context/knowledge/how-to/run-a-feature.md`, and the feature template. Leave the vendored skills as they are. Wire the runner in a later change, after this repo has a remote the runner can clone.

Human gates that stay: confirm intent, approve the spec (and the design screens when they exist), approve the plan, resolve a spec-stop, merge, deploy.

## Alternatives Considered

### One session implements, reviews, and continues

- Pros: no handoff and no runner
- Cons: the reviewer shares the author's context, and later tasks run after a long chat
- Rejected: this is the failure the loop exists to avoid

### A parent agent that calls the next persona

- Pros: nothing outside the chat has to start the next hop
- Cons: ADR-0001 already rejects personas hiring personas, and the parent would paraphrase the spec into the child
- Rejected: the next session reads the spec file and a commit, not a summary

### The review session also applies the fixes

- Pros: one fewer hop
- Cons: the review grows into an implementation, and the next review is no longer independent of the fix
- Rejected: a fix is its own hop

### Keep a human paste between every hop, with a shorter prompt

- Pros: no runner to build
- Cons: the paste is the repetition this decision removes
- Kept only as the interim, until a remote and a runner exist

## Consequences

- Accepted on 2026-11-04. `repo-workflow`, the prompts, the operating model, the how-to, and the feature template state the loop.
- A cloud or automation runner is a follow-up. It needs a git remote. It must not run on `spec-stop`.
- Review, security, and test passes stay one fresh session. When the diff touches auth, input, or stored data, that review hop also reads `.cursor/agents/security-auditor.md` and still only writes findings.
- Enrolment, already `implementing`, uses the build loop from the next session. Its checkpoints are review hops, not human gates.
