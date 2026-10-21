# ADR-0004: The product is Sokong, assessed with Mara

## Status

Accepted

## Date

2026-10-21

## Context

The repository was a place to build a product, and the product was unnamed. The introduction is now stored at `context/product/sokong-and-mara.pdf`. It is a 146-page argument, not a requirements document. It defines Mara as a way to measure a nation by its family units, and Sokong as the program that supports struggling and deteriorating family units until they thrive.

The same document uses two status rules, imagines both a census and a caseload, and ends with a list of loose ends. Those are recorded in `context/product/open-questions.md` and are not resolved by this decision.

Web and mobile clients are still absent. The Rails API is still the only runtime.

## Decision

Sokong is the product. Mara is its assessment. The reading agents trust is `context/product/concepts.md`. The catalog of features is `context/product/master-feature-list.md`.

No catalog row is a PRD. A feature folder is created only when a human names the feature and the open questions that block it have answers in `open-questions.md`.

The app records and coordinates the program for community members, workers, benefactors, facilitators, nation planners, and families. Web and mobile clients will share the Rails API. This decision does not choose the first feature, the first locality, or the operator.

## Alternatives Considered

### Treat the PDF as the PRD and start the Sarah story in code

- Pros: the simulation is vivid and looks like a backlog
- Cons: the status rules conflict, consent is unfinished, and the source says the program is only "sort of" defined
- Rejected: a catalog and the open questions come first

### Leave the product domain unset until a formal PRD exists

- Pros: avoids freezing a reading of a loose deck
- Cons: the next agent will invent an app, which is the failure ADR-0002's context tree exists to prevent
- Rejected: the domain is now named, and the unsettled parts are named with it

## Consequences

- `context/product/vision.md` and `AGENTS.md` describe Sokong. They no longer say the domain is unset.
- Agents do not invent features beyond the catalog, and do not answer Q1–Q16 in order to start a spec.
- Clients and a production host remain future work, still governed by ADR-0003.
