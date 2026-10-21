# Agent-orchestrated Rails API

This repository is the system of record for Sokong, a program that supports family units, measured with Mara. The introduction is [context/product/sokong-and-mara.pdf](context/product/sokong-and-mara.pdf). The feature catalog is [context/product/master-feature-list.md](context/product/master-feature-list.md). No feature has a PRD yet.

The first runtime is a Rails API. Web and mobile clients will share it, and neither client is in this tree yet.

Agents do not share a chat. They share this repo: specs, decisions, how-tos, postmortems, and code. You run the sequence. A spec session does not implement, and the session that writes the code does not approve the merge.

The full argument, including the gaps, is in [context/workflow/operating-model.md](context/workflow/operating-model.md).

## Layout

| Path | Role |
|---|---|
| `backend/` | Rails 8.1 API. `GET /up` is the only behavior so far. |
| `context/` | Product memory. Start at [context/README.md](context/README.md). |
| `.cursor/skills/` | Workflows from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills), plus `repo-workflow`. |
| `.cursor/agents/` | Review personas. A session reads one when the prompt says to. |
| `AGENTS.md` | What every agent must do in this repo. |
| `bin/ci` | The gate: style, dependency audit, Brakeman, tests. |

Skills are pinned at the commit in `.cursor/agent-skills.sha`. License of that pack is MIT.

## Run the API

Ruby 3.4.11.

```bash
cd backend
bundle install
bin/rails db:prepare
bin/rails server
```

Then request `GET /up`.

## Run the gate

```bash
bin/ci
```

## Start a feature

Use a fresh agent session per phase. Prompts are in [context/workflow/prompts.md](context/workflow/prompts.md). The short version:

1. Interview, until you confirm `intent.md`.
2. Spec, until you approve `spec.md`.
3. Plan, until you approve the tasks.
4. Implement one task and open a pull request.
5. Review in a different session.
6. Merge when `bin/ci` is green.

Deploy waits until you ask for it, and until an ADR names a real host. The address in `backend/config/deploy.yml` is a placeholder.
