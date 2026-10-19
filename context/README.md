# Context index

This tree is the product memory. Read it before planning or coding. Write back before you end a session that learned something.

| Path | What it is |
|---|---|
| `product/vision.md` | What this repo is for. The product domain is not chosen yet. |
| `workflow/operating-model.md` | What is feasible, what is missing, and how a feature moves. |
| `workflow/prompts.md` | The prompt for each fresh agent session. |
| `workflow/definition-of-done.md` | The standing bar for every change. |
| `requirements/features/` | One folder per feature. Status lives in that folder's README. |
| `decisions/` | ADRs. Append-only. Directory pointer: `/.adr-dir`. |
| `knowledge/how-to/` | Procedures worth repeating. |
| `knowledge/postmortems/` | What broke, why, and what changed. |

No feature is in progress. The running app is a Rails API with `GET /up` only.

Agents follow `.cursor/skills/repo-workflow/SKILL.md`.
