# Operating model

This is the answer to "can we run product development as a chain of agents, with the repo as their memory?"

## What is feasible

Yes, if you stay the orchestrator.

The skills pack already maps onto the chain you described:

| You want | Skill the agent follows |
|---|---|
| Interview you about a feature | `interview-me` |
| Stress a vague idea | `idea-refine` |
| Write the spec and stop | `spec-driven-development` |
| Break it into tasks | `planning-and-task-breakdown` |
| Implement in small slices | `incremental-implementation`, `test-driven-development` |
| Design the HTTP contract | `api-and-interface-design` |
| Review a pull request | `code-review-and-quality` and `.cursor/agents/code-reviewer.md` |
| Look for missing tests | `.cursor/agents/test-engineer.md` |
| Look for vulnerabilities | `security-and-hardening` and `.cursor/agents/security-auditor.md` |
| Fix a red build | `debugging-and-error-recovery` |
| Record why | `documentation-and-adrs` |
| Set up a pipeline | `ci-cd-and-automation` |
| Deploy | `shipping-and-launch`, only after you ask |
| Watch production | `observability-and-instrumentation`, once something is deployed |

Cursor loads a skill when the task matches its description, and this repo tells it to start at `repo-workflow`. Each session reads `context/` and writes its artifact back. The next session does not need the previous chat.

`GET /up` plus `bin/ci` is the loop in miniature: a behavior, a test, and a gate. Real features use the same loop.

## What you should not automate away

ADR-0001 holds through plan approval. ADR-0007 holds after it.

A single agent that interviews, writes the spec, and then codes will paraphrase a direction nobody accepted. Fresh sessions through `plan-approved` are the point of that split.

After the plan is approved, the implementer runs the tasks. Review is a subagent with a clean context: it sees the spec and the diff, not the implementation transcript. The implementer does not grade its own diff.

Human gates that stay:

1. Confirm the interview (`intent-confirmed`).
2. Approve the spec (`spec-approved`) before anyone plans or codes. When the spec has a screen, accept the design screenshots first. Status stays `spec-draft` until that approval.
3. Approve the plan when there is more than one task.
4. Decide a task-loop stop: a finding that would change the spec or the task, a finding still open after one fix attempt, or the feature branch ready for `main`. The implementer merges each task pull request into `feature/<slug>`.
5. Deploy to production. No agent holds production credentials by default.

## Gaps

These are real. The scaffold does not pretend they are done.

1. **Nothing starts the next session for you.** Skills are instructions, not a queue. `context/workflow/prompts.md` is the handoff. Cursor automations can later open a coding agent when you flip a feature to `plan-approved`. That automation is not wired, and it should not skip spec approval.

2. **Interview only works with you in the thread.** It is one question at a time. File the confirmed intent before you open the spec session, or the spec session will guess.

3. **Personas are files the implementer spawns.** `code-reviewer`, `security-auditor`, `test-engineer`, and `web-performance-auditor` sit in `.cursor/agents/`. The Run prompt spawns them by those names. A subagent comment is the review record.

4. **Claude Code slash commands are not here.** `/spec`, `/plan`, `/build`, `/review`, and `/ship` belong to that adapter. In Cursor, name the skill or paste the prompt.

5. **The pack is not a Rails or mobile guide.** Stack rules are `.cursor/rules/rails-api.mdc` and ADR-0003. The testing checklist under `.cursor/references/testing-patterns.md` uses JavaScript examples. Follow the principles, not the syntax. There is no mobile skill. Add one when that client starts.

6. **Deploy and monitor are procedures without systems.** Kamal and Docker files were generated with Rails. The host in `config/deploy.yml` is a placeholder. There is no error tracker, no metrics backend, and no on-call. `/up` is the only health signal. Build those when a feature needs production, in their own approved spec.

7. **CI runs where a GitHub repo exists.** The workflow is `.github/workflows/ci.yml`. Until this project is on GitHub, the gate you can trust is `bin/ci` locally.

8. **The product questions have human answers.** Sokong and Mara are in `context/product/`. Answers from 2026-10-28 are in `open-questions.md`. Agents must not reopen one with a guess. F24, F34, F36, and F37 are deferred on purpose. A PRD starts from `context/product/master-feature-list.md` only after a human picks the row.

9. **Two clients will freeze a sloppy API.** The web client is Nuxt and the mobile client is Flutter (ADR-0005). Neither is scaffolded. The contract is written in the feature spec before the controller, and it stays unversioned until a second client needs a break.

10. **Upstream skills will drift.** Update on purpose with `scripts/sync-agent-skills.sh`. Do not edit vendored skills. Put repo rules in `repo-workflow`.

11. **A context tree rots if status is not updated.** The feature README is the board. A session that writes `spec.md` and leaves status at `interviewing` has failed the skill.

12. **The implementer does not grade its own diff.** It spawns a persona. The persona gets the spec path and the diff.

## How a feature moves

Diagrams for the sessions, the status machine, the feature branch, and the review passes are in [flows.md](flows.md).

```
you have an idea
  → interview session writes intent.md and stops
  → you confirm
  → spec session writes spec.md and stops
  → when the spec has a screen, a design session writes design.md and screenshots and stops
  → you approve the spec and, when they exist, the screens
  → plan session writes plan.md and tasks.md and stops
  → you approve
  → one implementer runs every remaining task
  → for each task it opens a pull request into the feature branch, spawns the review personas, applies the act-on findings, and merges
  → it stops if a finding would change the spec or the task
  → when no tasks remain, and the feature has a screen, it records one video walkthrough
  → you merge the feature branch to main
  → deploy and monitor only when you have asked for production
```

Status names and file paths are in `repo-workflow`. Enrolment's task pull requests merge into `feature/enrolment`, which is still ahead of `main`.

## What is already in place

- Pinned skills, references, and personas
- `repo-workflow`, always-on project rule, Rails rule
- Context index, four ADRs, the Sokong introduction, the feature catalog, templates, prompts, definition of done
- Rails API, `GET /up`, integration test, `bin/ci`
- Root GitHub Actions workflow and Dependabot config aimed at `backend/`

## What to do when the first real feature shows up

1. Pick a row in `context/product/master-feature-list.md`. Answer the open questions that block it.
2. Start an interview session with the prompt in `prompts.md`. Answer one question at a time. Confirm the intent file.
3. Run spec, then design when the spec has a screen, then plan, each in a new session, and approve each.
4. Paste the Run prompt once. The implementer takes every remaining task, reviews it through the personas, and merges each task pull request into the feature branch.
5. When it stops with no tasks left, watch the video walkthrough if the feature has a screen, then merge the feature branch to `main`.

Leave deploy until that feature needs a server. Write the hosting ADR then, and replace the placeholder in `config/deploy.yml` in the same change.
