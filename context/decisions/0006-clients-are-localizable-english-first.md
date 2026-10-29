# ADR-0006: Clients are localizable, English first

## Status

Accepted

## Date

2026-10-28

## Context

Q15 asked which human languages the first web and mobile clients speak. The source document is in English. The product names are Malay. The framework is not a Malaysian release (Q2).

ADR-0005 names the clients, Nuxt and Flutter, and left the languages open. The human answered on 2026-10-28: both frontends can be localized into any language, and the first language is English.

Neither client is scaffolded. A string frozen in English would be expensive to unwind after the first screens exist.

## Decision

User-facing copy in the web client and the mobile client is localizable. The first locale is English. Adding a language later is a translation, not a new client and not a new feature.

This decision does not choose a localization library. The client spec names that, against the current Nuxt and Flutter docs, when a human asks for the client.

## Alternatives Considered

### English only, and translate the app later by editing strings

- Pros: nothing to set up before the first screen
- Cons: the human asked for localization from the start, and hardcoded copy is the thing that is expensive to undo
- Rejected: the first locale is English, and the mechanism has to allow another language

### Ship Malay and English together

- Pros: the product names are Malay, and the author is Malay
- Cons: the human said the first language is English, and the framework is not a Malaysian release
- Rejected: Malay can be added as a locale when someone asks for it

## Consequences

- A client spec requires externalized copy before screens are built.
- English is the locale a test and a first user can rely on.
- The Rails API stays as ADR-0003 wrote it. Localized copy is a client concern unless a later spec says the API returns it.
- ADR-0005 still names Nuxt and Flutter. This ADR does not replace it.
