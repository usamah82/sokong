---
name: repo-workflow
description: Routes work through this repo's feature folders, ADRs, and human gates. Use when starting a session, speccing or planning a feature, handing work to another agent, recording a decision, writing a how-to or postmortem, or deciding whether code is allowed yet.
---

# Repo workflow

## Overview

This repository is the memory shared by every agent. Chats are not. A later agent knows only what was written under `context/` and in the code. This skill says where that memory goes, which upstream skill to follow, and when to stop for a human.

## When to Use

- The start of a session
- The ask is a feature, a spec, a plan, a review, a deploy, or "what should we build"
- You are about to write an ADR, a how-to, or a postmortem
- You are unsure whether you are allowed to write code

Do not use this skill as a substitute for the upstream workflow skill. It only places that workflow in this repo.

## Do this first

1. Read `context/README.md`.
2. Read `AGENTS.md` if you have not already.
3. If a feature slug is in the prompt, read that folder's `README.md` before any other file in it.
4. Open `.cursor/skills/using-agent-skills/SKILL.md` and follow the single upstream skill for the phase below.

## Where work lives

Copy `context/requirements/features/_template/` to `context/requirements/features/<slug>/`. Slug is lowercase words separated by hyphens. Never implement the `_template` folder itself.

| Phase | Upstream skill | Write |
|---|---|---|
| Interview | `interview-me` | `intent.md`. One question per turn. Stop when the human confirms the intent. |
| Shape a vague idea | `idea-refine` | Notes in `intent.md` until the human picks a direction. |
| Spec | `spec-driven-development` | `spec.md`. Then stop. |
| Design | `frontend-ui-engineering` | When the spec has a screen: `design.md`, `design/preview.html`, and 390px screenshots. Then stop. Status stays `spec-draft`. |
| Plan | `planning-and-task-breakdown` | `plan.md` and `tasks.md`. Then stop for plan approval. |
| Implement | `incremental-implementation` and `test-driven-development` | One green slice, then handoff action `review`. |
| API shape | `api-and-interface-design` | Contract notes in `spec.md` before the controller exists. |
| Review | `code-review-and-quality` | `review.md` and the next handoff action. No product edits. |
| Fix | `incremental-implementation` and `test-driven-development` | In-scope findings only, then handoff action `review`. |
| Security pass | `security-and-hardening` | Only when a human asks for a pass outside the loop. The review hop already reads the auditor when the diff touches auth, input, or stored data. |
| Test gap pass | `test-driven-development` | Only when a human asks. The review hop already files missing tests of specified behavior as findings. |
| Debug | `debugging-and-error-recovery` | A failing test first, then the fix. |
| Decision | `documentation-and-adrs` | The next `context/decisions/NNNN-title.md`. |
| Ship | `shipping-and-launch` and `ci-cd-and-automation` | Only after a human asks to deploy. Production host is not decided. |
| Learn | this skill | `context/knowledge/how-to/` or `context/knowledge/postmortems/`. |

The upstream spec skill defaults to `tasks/plan.md` and `tasks/todo.md`. This repo overrides that. The feature folder is the tracker.

When a plan adds tables, models, HTTP routes, or a processing pipeline, `plan.md` also has a technical map: the new tables and columns, the models and other objects, the routes, and the flow from request to saved rows. A Mermaid diagram is enough. Skip the map when the change has none of those. Leave the vendored planning skill as it is. This rule is the repo's addition.

## Status

Set `Status` in the feature `README.md` to exactly one of:

`interviewing` → `intent-confirmed` → `spec-draft` → `spec-approved` → `planning` → `plan-approved` → `implementing` → `in-review` → `done`

`spec-stop` halts the build loop from `implementing`. `parked` is allowed from any state. Say why in the README.

Only a human moves a feature to `intent-confirmed`, `spec-approved`, or `plan-approved`. An agent may set `spec-draft`, `planning`, `implementing`, `spec-stop`, `in-review`, and `done` when it finishes that phase's artifact. `spec-stop` means a finding needs a human. `in-review` means auto-merge is queued and the pull request is not merged yet. `done` means the ready hop's pull request is merged.

## Gates

Stop the turn, even if you could keep going:

- After the interview's confirmed intent. Do not write the spec in that same turn.
- After `spec.md` is saved. Do not plan or write code. This matches `spec-driven-development`.
- After the design screenshots, when the spec has a screen. Do not plan or write product code. A picture that changes behavior is written back into `spec.md`. Status stays `spec-draft` until the human approves the spec.
- After the plan. Approval is a human action, including when one task remains. The build loop starts only at status `plan-approved`.
- After one build-loop hop. Write `handoff.md` and stop. Do not start the next action in this session.
- On `spec-stop`. Wait for the human to change the spec or tasks, or to say how the loop should continue.
- On `ready`. Merge the pull request in that same review hop (ADR-0008).
- Before any production deploy.

A typo, a failing test for already-accepted behavior, or a dependency bump does not need a new feature folder. Name the existing spec or ADR in the commit instead.

## Agents do not hire agents

You are one role for this session. Do not spawn another persona to continue the lifecycle. The upstream rule is in `.cursor/references/orchestration-patterns.md`. The human, or later a runner outside the chat, starts the next session. If a follow-up is needed, name it in your final message and point at `context/workflow/prompts.md`.

The build loop below is that handoff. It is one hop in this session, not a parent agent calling the next hop.

## Build loop

ADR-0007. This starts at status `plan-approved` and runs while status is `implementing`. The prompt is `Continue the build loop` in `context/workflow/prompts.md`.

Read `handoff.md` in the feature folder. Do that action once. If the file is missing and status is `plan-approved` or `implementing`, the action is `implement` for the next unchecked task. If `Claim` is `taken`, stop and say the last hop is unfinished, unless the human's message in this session tells you to take over that hop. Then finish that one action. If status is `spec-stop` or `done`, stop, unless the human's message in this session resolved a spec-stop. If status is `in-review`, follow the merge section.

A `Checkpoint` heading in `tasks.md` is a review of the tasks above it. It is not a human gate. When a review is clean and those tasks are checked, verify the checkpoint bullets and check the box in the same review hop. Do not open a pull request whose only change is the checkpoint.

### Handoff

Write `handoff.md` with these fields only. Do not summarize the spec or the implementation chat.

```markdown
# Handoff

Slug:
Action:
Task:
Base:
Claim: open
Cycles: 0
Fix-round: 0
Continue: no
Note:
```

`Action` is `implement`, `review`, `fix`, `spec-stop`, or `ready`. `Base` is the full commit sha the next review diffs from (`Base..HEAD`). `Task` is the task heading. `Note` is what is left, or the spec-stop reason.

The claim commit sets `Claim: taken` and does not change product code. For `implement` or `fix`, that commit sets `Base` to the current HEAD. A review hop's claim commit leaves `Base` unchanged, so the diff stays `Base..HEAD`. The slice commit comes after the claim and `bin/ci` passes. The last commit sets the next action and `Claim: open`, increments `Cycles` by one, and leaves `Base` unchanged. A second runner that sees `Claim: taken` stops.

On the first slice, open a pull request when the feature does not already have one. Record the link in the feature README. Leave status `implementing`.

### Actions

| Action | Do | Then set |
|---|---|---|
| `implement` | One green slice of `Task`, or the next unchecked task. Follow `api-and-interface-design` when the slice changes HTTP. | `review`. `Fix-round` is `0`. Leave `Base` as the sha from before the slice. `Continue: yes` and a `Note` when the task acceptance is still open. Check the task when its acceptance is true, and set `Continue: no`. |
| `review` | Read `spec.md`, `tasks.md`, and the diff `Base..HEAD`. Do not read the implementation chat. Read `.cursor/agents/code-reviewer.md` and follow `code-review-and-quality`. When the diff touches auth, input, or stored data, also read `.cursor/agents/security-auditor.md`. Read `.cursor/agents/test-engineer.md` for missing tests of behavior the spec already requires. Write `review.md`. Do not edit product code. | See the verdicts below. |
| `fix` | Apply only the in-scope findings in `review.md` for this slice. | `review`. Do not change `Fix-round`. |
| `spec-stop` | Set status to `spec-stop`. Put the reason in `Note`. | Stop. |
| `ready` | Merge the open pull request, as in the merge section. | `done` when the pull request is merged. `in-review` when auto-merge is only queued. |

Replace `review.md` each review hop:

```markdown
# Review

Task:
Base:
Verdict:

## In scope

## Spec stop
```

`Verdict` is `fix`, `implement`, `spec-stop`, or `ready`. Omit an empty section.

A finding is in scope when the approved spec and tasks already require the remedy. A finding is a spec-stop when the remedy needs a changed spec sentence, a changed task or acceptance criterion, or a new ADR. When both kinds are present, or when you cannot tell, the verdict is `spec-stop`. Do not apply fixes in that hop.

Verdicts:

- In-scope findings, and `Fix-round` is `0` or `1`: set `fix` and add one to `Fix-round`.
- In-scope findings, and `Fix-round` is `2`: `spec-stop` with reason `not converging`.
- No findings, a later task or checkpoint remains: `implement`.
- No findings, and every task and checkpoint is checked: `ready`.

One green slice per session. Do not start a second slice, the review of your own slice, or the next task in this session. Code is allowed at `plan-approved` or `implementing` only.

### Merge

ADR-0008. The review hop merges when its verdict is `ready`. A clean review that still has a later task or checkpoint sets `implement` and does not merge.

Merge the open pull request whose head is the current branch, with a merge commit: `gh pr merge --merge`. Do not delete the branch. Required checks must be green, or still running. When they are still running, enable auto-merge with `gh pr merge --merge --auto`, set status to `in-review`, set action `ready`, and set `Note` to `auto-merge queued`.

When a required check is failing, do not merge. Set `fix` when `Fix-round` is `0` or `1` and the failure is a red test or lint for behavior the spec already requires. Otherwise set `spec-stop` and name the check in `Note`.

When the pull request is merged, set status to `done` and stop. A later hop that finds `in-review` and a merged pull request sets `done` and stops. A later hop that finds auto-merge queued and checks still pending stops. A later hop that finds a failing required check follows the red-check rule above.

## Decisions, how-tos, postmortems

- ADR when a choice would be expensive to reverse, or when an agent would otherwise make it again. Match the headings already used under `context/decisions/`.
- How-to when a procedure will be repeated. Timeless steps, not a diary.
- Postmortem when something broke and the next agent needs the cause. Copy `context/knowledge/postmortems/_template.md`.

Link the feature, ADR, or pull request. Do not duplicate the same decision in all three places.

## Verification

- [ ] `context/README.md` was read this session
- [ ] The feature README status matches the artifact you wrote
- [ ] You stopped at the gate for this phase
- [ ] A build-loop session wrote `handoff.md` for one action and did not start the next
- [ ] Code changes, if any, were allowed by status `plan-approved` or `implementing`
- [ ] `bin/ci` passed before you called a code change done
- [ ] A new architectural choice has an ADR number that continues the sequence
