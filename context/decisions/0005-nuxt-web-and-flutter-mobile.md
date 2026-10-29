# ADR-0005: Nuxt for web, Flutter for mobile

## Status

Accepted

## Date

2026-10-28

## Context

ADR-0003 left the web and mobile clients unnamed and unscaffolded. The API in `backend/` is the shared contract. On 2026-10-28 the human named the two clients while answering Q15 in `context/product/open-questions.md`. Q15 asked which human languages those clients speak. This decision records only the technologies. The languages are ADR-0006.

No feature PRD is approved, so there is still nothing for a client to show.

## Decision

The web client will be a Nuxt application. The mobile client will be a Flutter application. Each is a sibling of `backend/` when its own spec says to create it. Both talk to the Rails API. Neither is scaffolded by this decision.

Do not version the URL space until a second client needs a change the first client cannot take. That constraint stays as ADR-0003 wrote it.

## Alternatives Considered

### Leave the clients unnamed until a client spec

- Pros: avoids choosing a framework before a screen exists
- Cons: the human already chose, and the next agent would choose again
- Rejected: an unnamed client is how a third framework appears

### One client technology for web and mobile

- Pros: one UI codebase
- Cons: the human named two
- Rejected: Nuxt does not produce the mobile app, and Flutter is not the web app

## Consequences

- A client spec names Nuxt or Flutter before any app directory is created.
- CORS stays closed until a client origin is named (ADR-0003).
- The first locale is English, and both clients are localizable. That is ADR-0006.
- Rails remains the API (ADR-0003). This ADR does not replace it.
