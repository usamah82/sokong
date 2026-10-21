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

The pack is explicit, and this repo adopts that rule in ADR-0001. You run the sequence. An agent does not hire the next agent.

A single "software factory" agent that interviews, codes, and reviews itself will paraphrase the spec at every hop and then approve its own diff. Fresh sessions are the point of the split: the reviewer never saw the implementation chat, only the spec and the diff.

Human gates that stay, even later:

1. Confirm the interview (`intent-confirmed`).
2. Approve the spec (`spec-approved`) before anyone plans or codes.
3. Approve the plan when there is more than one task.
4. Merge the pull request. A review agent recommends.
5. Deploy to production. No agent holds production credentials by default.

## Gaps

These are real. The scaffold does not pretend they are done.

1. **Nothing starts the next session for you.** Skills are instructions, not a queue. `context/workflow/prompts.md` is the handoff. Cursor automations can later open a coding agent when you flip a feature to `plan-approved`. That automation is not wired, and it should not skip spec approval.

2. **Interview only works with you in the thread.** It is one question at a time. File the confirmed intent before you open the spec session, or the spec session will guess.

3. **Personas do not auto-load.** `code-reviewer`, `security-auditor`, `test-engineer`, and `web-performance-auditor` sit in `.cursor/agents/`. The review prompt tells the agent to read the file.

4. **Claude Code slash commands are not here.** `/spec`, `/plan`, `/build`, `/review`, and `/ship` belong to that adapter. In Cursor, name the skill or paste the prompt.

5. **The pack is not a Rails or mobile guide.** Stack rules are `.cursor/rules/rails-api.mdc` and ADR-0003. The testing checklist under `.cursor/references/testing-patterns.md` uses JavaScript examples. Follow the principles, not the syntax. There is no mobile skill. Add one when that client starts.

6. **Deploy and monitor are procedures without systems.** Kamal and Docker files were generated with Rails. The host in `config/deploy.yml` is a placeholder. There is no error tracker, no metrics backend, and no on-call. `/up` is the only health signal. Build those when a feature needs production, in their own approved spec.

7. **CI runs where a GitHub repo exists.** The workflow is `.github/workflows/ci.yml`. Until this project is on GitHub, the gate you can trust is `bin/ci` locally.

8. **The product is named, and several definitions are not.** Sokong and Mara are in `context/product/`. Agents must not fill `context/product/open-questions.md` with a guess. A PRD starts from `context/product/master-feature-list.md` only after a human picks the row and the questions that block it are answered.

9. **Two clients will freeze a sloppy API.** Web and mobile are not scaffolded. The contract is written in the feature spec before the controller, and it stays unversioned until a second client needs a break.

10. **Upstream skills will drift.** Update on purpose with `scripts/sync-agent-skills.sh`. Do not edit vendored skills. Put repo rules in `repo-workflow`.

11. **A context tree rots if status is not updated.** The feature README is the board. A session that writes `spec.md` and leaves status at `interviewing` has failed the skill.

12. **Same-session self-review is weak.** Use a second session, or a review bot, on the pull request. Give it the spec path and the diff, not the coding transcript.

## How a feature moves

```
you have an idea
  → interview session writes intent.md and stops
  → you confirm
  → spec session writes spec.md and stops
  → you approve
  → plan session writes plan.md and tasks.md and stops
  → you approve
  → coding session implements one task, opens a PR
  → a different session reviews against the spec
  → bin/ci is green
  → you merge
  → deploy and monitor only when you have asked for production
```

Status names and file paths are in `repo-workflow`.

## What is already in place

- Pinned skills, references, and personas
- `repo-workflow`, always-on project rule, Rails rule
- Context index, four ADRs, the Sokong introduction, the feature catalog, templates, prompts, definition of done
- Rails API, `GET /up`, integration test, `bin/ci`
- Root GitHub Actions workflow and Dependabot config aimed at `backend/`

## What to do when the first real feature shows up

1. Pick a row in `context/product/master-feature-list.md`. Answer the open questions that block it.
2. Start an interview session with the prompt in `prompts.md`. Answer one question at a time. Confirm the intent file.
3. Run spec, then plan, each in a new session, and approve both.
4. Let a coding agent implement the first task and open a pull request.
5. Run a review session that has not seen the coding chat.
6. Merge only when `bin/ci` is green and the review has no unresolved correctness or security findings.

Leave deploy until that feature needs a server. Write the hosting ADR then, and replace the placeholder in `config/deploy.yml` in the same change.
