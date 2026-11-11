# ADR-0007: Run the task loop without per-task human gates

## Status

Accepted

## Date

2026-11-11

## Context

ADR-0001 keeps the human as the orchestrator. That still holds through plan approval: interview, spec, design, and plan each stop so a wrong product direction stays cheap to reverse.

After `plan-approved`, the same rule made every task its own session. The human started implementation, then a review session, then security and tests when asked, then merged the task pull request, then started the next task. Those gates were go-aheads. The spec and the task list were already approved.

Review still has to be a fresh context. An implementer that grades its own diff paraphrases the spec and then approves it. Cursor's Agent SDK, and the editor, can spawn the personas in `.cursor/agents/` as subagents. A subagent starts with a clean context. The parent passes the spec path and the diff. The subagent does not see the implementation transcript. Docs: [TypeScript SDK subagents](https://cursor.com/docs/sdk/typescript).

## Decision

Through `plan-approved`, ADR-0001 stands. The human starts each of those sessions and is the one who sets `intent-confirmed`, `spec-approved`, and `plan-approved`.

After `plan-approved`, one implementer runs every remaining task. The human starts that session once, with the Run prompt in `context/workflow/prompts.md`. The implementer may spawn only these personas, by the names on `.cursor/agents/*.md`:

- `code-reviewer`, on every task pull request
- `security-auditor`, when the review says the diff needs it
- `test-engineer`, when a review says coverage is short
- `web-performance-auditor`, when a review says performance needs a pass

Those four comment on the pull request and do not edit the branch. They do not spawn anyone else. The implementer does not review its own diff.

The implementer acts on the bands those personas already use for "fix before merge":

| Persona | Act on | Leave |
|---|---|---|
| `code-reviewer` | Critical, Required | Optional, Nit |
| `security-auditor`, `test-engineer`, `web-performance-auditor` | Critical, High, Medium | Low |

`bin/ci` from the repository root is green before the task pull request opens and again before it merges. The base of that pull request is the long-running feature branch, `feature/<slug>`. The implementer merges it there, checks the task, and takes the next unchecked task. A checkpoint is checked after the tasks above it. It does not get a pull request.

The implementer stops and sets `in-review`, with the reason in the feature README, in two cases:

1. A finding can be fixed only by changing `spec.md` or that task's acceptance. The implementer does not edit the spec.
2. No unchecked tasks remain. The human merges `feature/<slug>` into `main`, then sets `done`.

If the same act-on finding is still open after one fix attempt, that is case 1 for this loop: stop, name the finding, and wait. Production deploy stays a separate human request. Hosting is undecided.

A local SDK agent that runs this loop passes `local.settingSources: ["project"]` so this repo's rules load, and it does not disallow the `task` tool. Cloud `autoCreatePR` targets the default base, so it is the wrong tool for a task pull request into the feature branch. A wrapper script around `Agent.create` is not part of this decision.

## Alternatives Considered

### Keep a human go-ahead before every review and every task merge

- Pros: a person sees each diff
- Cons: the approval is a rubber stamp once the plan is accepted, and the feature waits on that click
- Rejected: the human already approved the plan

### Let the implementer review its own diff

- Pros: one context, no spawn
- Cons: the reviewer remembers why the code was written and misses what it rationalized
- Rejected: the subagent exists so the review is a clean context

### One agent from interview through deploy

- Pros: one instruction for the whole feature
- Cons: spec and plan approval are the cheap place to stop a wrong product
- Rejected: those gates stay with the human, as in ADR-0001

## Consequences

- ADR-0001 stays in force through plan approval, for production deploy, and for the rule that personas do not call personas. This ADR supersedes it only for the task loop.
- `repo-workflow`, `AGENTS.md`, and the project rule allow this spawn and no other.
- The vendored orchestration note is unchanged. The repo rule is the exception.
- Status stays `implementing` across task merges. `in-review` means the human has something to decide. `done` stays a human action, after the feature branch is on `main`.
