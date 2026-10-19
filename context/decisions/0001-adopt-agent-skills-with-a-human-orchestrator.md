# ADR-0001: Adopt agent-skills, with a human orchestrator

## Status

Accepted

## Date

2026-10-19

## Context

We want agents to spec, implement, review, test, deploy, and watch the product. The workflows for those jobs already exist as [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT). Cursor discovers project skills from `.cursor/skills/` and does not discover persona files on its own.

The same pack's orchestration note says the human, or a slash command the human runs, is the orchestrator. Personas do not call personas. A meta-agent that interviews, then codes, then reviews adds a summary at every handoff and skips the moment where a wrong product direction is cheap to stop.

## Decision

Vendor the pack at the commit in `.cursor/agent-skills.sha`. Keep shared checklists in `.cursor/references/` and personas in `.cursor/agents/`. Add one project skill, `repo-workflow`, for paths and gates. Do not edit upstream skill files.

The human starts each phase in a fresh session, using `context/workflow/prompts.md`. Spec approval and merge stay human actions.

## Alternatives Considered

### One agent that owns the whole lifecycle

- Pros: fewer sessions to click through
- Cons: the implementing context reviews its own work; handoffs paraphrase the spec
- Rejected: worse review, and it fights the pack we are adopting

### Install skills only on a laptop with `npx skills add`

- Pros: smaller git history
- Cons: a cloud agent on a fresh clone would not see them; a one-skill install omits `references/`
- Rejected: the skills have to be in the repo that the agents clone

### Paste every skill into an always-on rule

- Pros: nothing to discover
- Cons: the prompt fills with workflows that are not in play
- Rejected: Cursor's own split is short rules plus skills on demand

## Consequences

- Updating the pack is `scripts/sync-agent-skills.sh`, then a commit of the new SHA.
- `/spec` and `/plan` from the Claude Code adapter are not installed. Prompts name the skill instead.
- A review session must be told to read `.cursor/agents/code-reviewer.md`. Cursor will not load it automatically.
