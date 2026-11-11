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
| Plan | `planning-and-task-breakdown` | `plan.md` and `tasks.md`. Then stop for plan approval if more than one task remains. |
| Implement | `incremental-implementation` and `test-driven-development` | Code, tests, and checked tasks. After `plan-approved`, every remaining task, per ADR-0007. |
| API shape | `api-and-interface-design` | Contract notes in `spec.md` before the controller exists. |
| Review | `code-review-and-quality` | A review comment on the task PR. The implementer spawns `code-reviewer`. The persona does not edit the branch. |
| Security pass | `security-and-hardening` | The implementer spawns `security-auditor` when a review says the diff needs it. Comment only. |
| Test gap pass | `test-driven-development` | The implementer spawns `test-engineer` when a review says coverage is short. Comment only. |
| Performance pass | `performance-optimization` | The implementer spawns `web-performance-auditor` when a review says performance needs a pass. Comment only. |
| Debug | `debugging-and-error-recovery` | A failing test first, then the fix. |
| Decision | `documentation-and-adrs` | The next `context/decisions/NNNN-title.md`. |
| Ship | `shipping-and-launch` and `ci-cd-and-automation` | Only after a human asks to deploy. Production host is not decided. |
| Learn | this skill | `context/knowledge/how-to/` or `context/knowledge/postmortems/`. |

The upstream spec skill defaults to `tasks/plan.md` and `tasks/todo.md`. This repo overrides that. The feature folder is the tracker.

When a plan adds tables, models, HTTP routes, or a processing pipeline, `plan.md` also has a technical map: the new tables and columns, the models and other objects, the routes, and the flow from request to saved rows. A Mermaid diagram is enough. Skip the map when the change has none of those. Leave the vendored planning skill as it is. This rule is the repo's addition.

## Status

Set `Status` in the feature `README.md` to exactly one of:

`interviewing` → `intent-confirmed` → `spec-draft` → `spec-approved` → `planning` → `plan-approved` → `implementing` → `in-review` → `done`

`parked` is allowed from any state. Say why in the README.

Only a human moves a feature to `intent-confirmed`, `spec-approved`, `plan-approved`, or `done`. An agent may set `spec-draft`, `planning`, `implementing`, and `in-review` when it finishes that phase's artifact.

After `plan-approved`, status stays `implementing` across task merges. `in-review` means the loop stopped for the human: a spec or task change, a finding that survived one fix attempt, or no tasks left.

## Gates

Stop the turn, even if you could keep going:

- After the interview's confirmed intent. Do not write the spec in that same turn.
- After `spec.md` is saved. Do not plan or write code. This matches `spec-driven-development`.
- After the design screenshots, when the spec has a screen. Do not plan or write product code. A picture that changes behavior is written back into `spec.md`. Status stays `spec-draft` until the human approves the spec.
- After the plan, when more than one task is left. A single small task may be implemented in a later turn of the same session only if the human already approved the spec and asked you to build it.
- During the task loop, when a finding can be fixed only by changing `spec.md` or that task's acceptance. Say so in the feature README and set `in-review`. Leave the spec unchanged.
- During the task loop, when the same act-on finding is still open after one fix attempt. Set `in-review` and name the finding.
- When no unchecked tasks remain. Set `in-review`. The human merges `feature/<slug>` into `main`, then sets `done`.
- Before any production deploy.

A typo, a failing test for already-accepted behavior, or a dependency bump does not need a new feature folder. Name the existing spec or ADR in the commit instead.

## Who starts the next session

Through plan approval, you are one role. Do not spawn another persona to continue the lifecycle. The human runs the next session. If a follow-up is needed, name it in your final message and point at `context/workflow/prompts.md`.

After `plan-approved`, ADR-0007 is the exception. The implementer runs every remaining task and may spawn `code-reviewer`, `security-auditor`, `test-engineer`, and `web-performance-auditor`. Those four comment on the task pull request and do not edit the branch, and they do not spawn anyone. The implementer merges that pull request into `feature/<slug>`. The human merges that branch into `main`.

The vendored note in `.cursor/references/orchestration-patterns.md` still says personas do not call personas. This section is the repo's exception. Do not edit that file.

## Decisions, how-tos, postmortems

- ADR when a choice would be expensive to reverse, or when an agent would otherwise make it again. Match the headings already used under `context/decisions/`.
- How-to when a procedure will be repeated. Timeless steps, not a diary.
- Postmortem when something broke and the next agent needs the cause. Copy `context/knowledge/postmortems/_template.md`.

Link the feature, ADR, or pull request. Do not duplicate the same decision in all three places.

## Verification

- [ ] `context/README.md` was read this session
- [ ] The feature README status matches the artifact you wrote
- [ ] You stopped at the gate for this phase
- [ ] Code changes, if any, were allowed by status `plan-approved` or `implementing`
- [ ] `bin/ci` passed before you called a code change done
- [ ] A new architectural choice has an ADR number that continues the sequence
