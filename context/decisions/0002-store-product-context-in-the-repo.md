# ADR-0002: Store product context in the repo

## Status

Accepted

## Date

2026-10-19

## Context

Agents do not share a chat. If the spec, the decision, and the postmortem live in a tool the next agent cannot read, the next agent will re-decide them. The repo is the one artifact every coding agent already has.

The spec skill's default plan path is `tasks/plan.md` at the repo root. One global task list collides as soon as two features exist.

## Decision

Keep product memory in `context/`:

- `context/requirements/features/<slug>/{README,intent,spec,plan,tasks}.md` is the tracker for that feature
- `context/decisions/` is the ADR log, numbered `0001` upward
- `context/knowledge/how-to/` and `context/knowledge/postmortems/` hold procedures and incidents

`context/README.md` is the index. Agents read it at the start of a session and update the feature status before they stop.

## Alternatives Considered

### A wiki or a ticket tracker as the source of truth

- Pros: comments, assignments, search
- Cons: agents in this repo would not see it unless we add a live integration
- Rejected for now: markdown in git is enough until search or permissions hurt. A later ADR can name a tracker and point the feature README at it.

### Root `tasks/plan.md`, as the upstream skill defaults

- Pros: matches the skill text with no override
- Cons: one plan for the whole product
- Rejected: `repo-workflow` overrides the path. The feature folder is the external tracker the skill allows.

## Consequences

- A feature that is only in a chat does not exist for the next agent.
- ADRs are not deleted when a decision changes. A new ADR supersedes the old one.
- The index can go stale if a session forgets to update a status. The skill's verification list checks that.
