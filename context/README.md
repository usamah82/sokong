# Context index

This tree is the product memory. Read it before planning or coding. Write back before you end a session that learned something.

| Path | What it is |
|---|---|
| `product/vision.md` | Sokong, the product. Start here. |
| `product/sokong-and-mara.pdf` | The introduction. Not a PRD. |
| `product/concepts.md` | Mara, Sokong, the roles, and the worked story. |
| `product/master-feature-list.md` | Catalog. No row is an approved spec. |
| `product/open-questions.md` | Human answers from 2026-10-28. Agents do not reopen them. |
| `workflow/operating-model.md` | What is feasible, what is missing, and how a feature moves. |
| `workflow/prompts.md` | The prompt for each fresh agent session. |
| `workflow/definition-of-done.md` | The standing bar for every change. |
| `requirements/features/` | One folder per feature. Status lives in that folder's README. |
| `decisions/` | ADRs. Append-only. Directory pointer: `/.adr-dir`. |
| `knowledge/how-to/` | Procedures worth repeating. |
| `knowledge/postmortems/` | What broke, why, and what changed. |

The enrolment spec (F01–F05) is approved in `requirements/features/enrolment/spec.md`. Status is `implementing`. The catalog is `product/master-feature-list.md`. The Rails API has locality claim, enrolment records, and an anonymous `POST /enrolments`. That post stores null coordinates until the nearest-center task. `GET /up` still returns success.

Agents follow `.cursor/skills/repo-workflow/SKILL.md`.
